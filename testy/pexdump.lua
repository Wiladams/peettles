--[[
	Dump the output of parsing a PE file.
	Call the parser, getting as much info on the file as possible
	print Lua valid output.
	
	Usage: luajit pexdump.lua filename.exe

	I can deal with any 'PE' file the parser can handle, typically .dll, .exe.
]]

package.path = "../?.lua;"..package.path

local ffi = require("ffi")
local bit = require("bit")

local enum = require("peettles.enum")
local peparser = require("peettles.peparser")
local peenums = require("peettles.penums")
local mmap = require("peettles.mmap_win32")
local binstream = require("peettles.binstream")
local putils = require("peettles.print_utils")
local COFF = require("peettles.parse_COFF")
local coff_utils = require("peettles.coff_utils")


local filename = arg[1];

if not filename then
	print("NO FILE SPECIFIED")
    return
end

local function printData(data, size)
	local bs, err = binstream(data, size)

	putils.printHex {
        stream = bs;
        buffer = ffi.new("uint8_t[?]", 16);
        offsetbits = 32;
        iterations = 256;
        verbose = false;
    }
end

function printTable(t)
	print("==== printTable ====")

	for k,v in pairs(t) do
		print(k,v)
	end
end

local function printDOSInfo(info)
	print("==== DOS ====")

	print("    Magic: ", string.format("%c%c", info.Header.e_magic[0], info.Header.e_magic[1]))
	print("PE Offset: ", string.format("0x%04x", info.Header.e_lfanew));
	print("Stub Size: ", string.format("0x%04x (%d)", info.Stub.Size, info.Stub.Size))

	-- print the stub in hex
	printData(info.Stub.Data, info.Stub.Size);
	print("---------------------")
end

local function printCOFFHeader(peinfo, header)
	print("---- BEGIN COFF Header ----")
	print("                Machine: ", string.format("0x%X", header.Machine), peenums.MachineType[header.Machine]);
	print("     Number Of Sections: ", header.NumberOfSections);
	print("        Time Date Stamp: ", string.format("0x%X", header.TimeDateStamp));
	print("Pointer To Symbol Table: ", header.PointerToSymbolTable);
	print("      Number of Symbols: ", header.NumberOfSymbols);
	print("Size of Optional Header: ", string.format("0x%04x (%d)", header.SizeOfOptionalHeader, header.SizeOfOptionalHeader));
	print("        Characteristics: ", string.format("0x%04x  (%s)", header.Characteristics,
		enum.bitValues(peenums.Characteristics, header.Characteristics, 32)));

	print("---- END COFF Header ----")

end


local function printDataDirectories(peinfo, directory)
	print("---- BEGIN PE Directory ----")
	print(string.format("%20s   %10s    %12s  %s", "name", "location", "size (bytes)", "section"))

	--printTable(directory)


	for name,dir in pairs(directory) do

		local vaddr = dir.VirtualAddress
		local sectionName = "UNKNOWN"

		if (vaddr > 0) and (peinfo.Sections ~= nil) then
			local sec, err = coff_utils.getEnclosingSection(peinfo.Sections, vaddr)

			if sec then
				sectionName = sec.StringName
			end
		end

		print(string.format("%20s   0x%08X    %12s   %s", 
			name, vaddr, string.format("0x%x (%d)", dir.Size, dir.Size), sectionName))

	end


	print("---- END PE Directory ----")
end

local function printPE32CommonOptionalHeader(peinfo, header)
    print("---- PE Optional Header ----")
    print("                   Magic: ", string.format("0x%04X",header.Magic))
    print("          Linker Version: ", string.format("%d.%d",header.MajorLinkerVersion, header.MinorLinkerVersion));
	print("            Size Of Code: ", string.format("0x%08x", header.SizeOfCode))
    print("              Image Base: ", header.ImageBase)
    print("       Section Alignment: ", header.SectionAlignment)
	print("          File Alignment: ", header.FileAlignment)
	print("  Address of Entry Point: ", string.format("0x%08X",header.AddressOfEntryPoint))
	print(string.format("            Base of Code: 0x%08X", header.BaseOfCode))
    print("               OSVersion: ", string.format("%d.%d", header.MajorOperatingSystemVersion, header.MinorOperatingSystemVersion))
    print("           SizeOfHeaders: ", string.format("%d", header.SizeOfHeaders))
    print("               Subsystem: ", string.format("%s (0x%04X)", peenums.Subsystem[header.Subsystem], header.Subsystem ))
end

local function printPE32OptionalHeader(peinfo, header)
    print("---- PE32 Optional Header ----")
    
    printPE32CommonOptionalHeader(peinfo, header)

	if header.BaseOfData then
		print(string.format("            Base of Data: 0x%08X", header.BaseOfData))
	end

    print(string.format("Number of Rvas and Sizes: 0x%08X (%d)", header.NumberOfRvaAndSizes, header.NumberOfRvaAndSizes))


	print("---------------------")
end

local function printPE32PlusOptionalHeader(peinfo, header)

	print("---- PE 32+ Optional Header ----")

    printPE32CommonOptionalHeader(peinfo, header)


	print(string.format("Number of Rvas and Sizes: 0x%08X (%d)", header.NumberOfRvaAndSizes, header.NumberOfRvaAndSizes))


	print("---------------------")
end

local function printPEHeader(peinfo, header)
    if (header.isPE32Plus) then
        printPE32PlusOptionalHeader(peinfo, header)
    else
        printPE32OptionalHeader(peinfo, header)
    end

    --printDataDirectory(peinfo, header.Directory)

    print("---------------------")
end

local function printSectionHeaders(peinfo, sections)
	print("---- BEGIN PE Sections ----")

	for name,section in pairs(sections) do
		print(".....................")
		print(string.format("             String Name: %s", section.StringName))
		print(string.format("         Virtual Address: 0x%08X", section.VirtualAddress))
		print(string.format("            Virtual Size: %d", section.VirtualSize))
		print(string.format("        Size of Raw Data: 0x%08X (%d)", section.SizeOfRawData, section.SizeOfRawData))
		print(string.format("     Pointer to Raw Data: 0x%08X", section.PointerToRawData))
		print(string.format("  Pointer to Relocations: 0x%08X", section.PointerToRelocations))
		print(string.format("  Pointer To Linenumbers: 0x%08X", section.PointerToLinenumbers))
		print(string.format("   Number of Relocations: %d", section.NumberOfRelocations))
		print(string.format("  Number of Line Numbers: %d", section.NumberOfLinenumbers))
		print(string.format("         Characteristics: 0x%08X  (%s)", section.Characteristics, 
			enum.bitValues(peenums.SectionCharacteristics, section.Characteristics)))

	end
	print("---- END PE Sections ----")
end


local function printImports(info)
	--print("'===== IMPORTS =====',")

	if not info.PE.Content.Imports then return false, "No Imports"; end

	for k,v in pairs(info.PE.Content.Imports) do
		print(k)
		for i, name in ipairs(v) do
			print(string.format("    %s",name))
		end

	end

	--print("---------------------")
end

local function printExports(info)
	print("===== EXPORTS =====")
	if (not info.PE.Content.Exports) then
		print("  NO EXPORTS")
		return ;
	end

	local res = info.PE.Content.Exports

	print("        Export Flags: ", string.format("0x%08X", res.Characteristics))
	print("     Time Date Stamp: ", string.format("0x%08X", res.TimeDateStamp))
	print("             Version: ", string.format("%d.%2d", res.MajorVersion, res.MinorVersion))
    print("               nName: ", string.format("0x%08X",res.nName))
    print("         Module Name: ", res.ModuleName)
    print("        Ordinal Base: ", res.nBase)
    print("   NumberOfFunctions: ", res.NumberOfFunctions);
    print("       NumberOfNames: ", res.NumberOfNames);
    print("  AddressOfFunctions: ", string.format("0x%08X",res.AddressOfFunctions));
    print("      AddressOfNames: ", string.format("0x%08X",res.AddressOfNames));
    print("AddressOfNameOrdinals: ", string.format("0x%08X", res.AddressOfNameOrdinals));

	--[[
	print(" = All Functions =")
	for k,v in pairs(reader.Export.AllFunctions) do
		if tonumber(v) then
			print (k, string.format("0x%x", v))
		else
			print(k, v)
		end
	end
--]]

	print(" = Ordinal Only = ")
	for k,v in pairs(info.PE.Content.Exports.OrdinalOnly) do
		if type(v) == "string" then
			print(k, v)
		else
			print (k, string.format("0x%x", v))
		end
	end

	print(" = Named Functions =")
	for i, entry in ipairs(info.PE.Content.Exports.NamedFunctions) do
		if type(entry.funcptr) == "string" then
			print(string.format("%4d %4d %50s %s",entry.ordinal, entry.hint, entry.name, entry.funcptr))
		else 
			print(string.format("%4d %4d %50s %s",entry.ordinal, entry.hint, entry.name, string.format("0x%08X", entry.funcptr or 0)))
		end
	end

	print("---------------------")
end

local function printResources(info)
	print("==== RESOURCES ====")
	if not info.PE.Content.Resources then
		print("  NO RESOURCES ")
		return false;
	end

	local function printDebug(level, ...)
		local cnt = 0;
		while cnt < level do
			io.write('    ')
			cnt = cnt + 1;
		end
		print(...)
	end

	local function printResourceData(entry)
		local buffer = ffi.new("uint8_t[?]", 16)

		-- get file offset for DataRVA
		local dataOffset = info:fileOffsetFromRVA(entry.DataRVA)
		local dataSize = entry.Size;
		--local bs = binstream(info.SourceStream._data, info.SourceStream._size, dataOffset, true);
		local bs = info.SourceStream:range(dataSize, dataOffset);
		-- print in hex
		putils.printHex(bs, buffer)
	end

	local function printDirectory(subdir, level)
		level = level or 1
		printDebug(level, "SUBDIRECTORY")
		printDebug(level, "          Level: ", subdir.level)
		printDebug(level, "   Is Directory: ", subdir.isDirectory)
		printDebug(level, "             ID: ", subdir.ID);
		
		-- It is Microsoft convention to use the 
        -- first three levels to indicate: resource type, ID, language ID
        if subdir.level == 1 then
			printDebug(level, "Entry ID (KIND): ", subdir.Kind, peenums.ResourceTypes[subdir.Kind])
        elseif subdir.level == 2 then
			printDebug(level, "Entry ID (NAME): ", subdir.ItemID)
        elseif subdir.level == 3 then
			printDebug(level, "Entry ID (LANGUAGE): ", subdir.LanguageID)
		end

		printDebug(level, "Characteristics: ", subdir.Characteristics);
		printDebug(level, "Time Date Stamp: ", subdir.TimeDateStamp);
		printDebug(level, "        Version: ", string.format("%d.%02d", subdir.MajorVersion, info.PE.Content.Resources.MinorVersion));
		printDebug(level, "  Named Entries: ", subdir.NumberOfNamedEntries);
		printDebug(level, "     Id Entries: ", subdir.NumberOfIdEntries);
		printDebug(level, "  == Entries ==")
		if subdir.Entries then
			--print("  NUM Entries: ", #subdir.Entries)
			for i, entry in ipairs(subdir.Entries) do 
				if entry.isDirectory then
					printDirectory(entry, level+1);
				elseif entry.isData then
					printDebug(level, "    DataRVA: ", string.format("0x%08X", entry.DataRVA));
					printDebug(level, "       Size: ",entry.Size);
					printDebug(level, "  Code Page: ", entry.CodePage);
					printDebug(level, "   Reserved: ", entry.Reserved);

					--printResourceData(entry);
				end
			end
		end
	end

	printDirectory(info.PE.Content.Resources)
end

local function printPEInfo(info)

	print("==== PE ====")
	print("             Signature: ", string.format("%c%c%c%c", info.Signature[0], info.Signature[1], info.Signature[2], info.Signature[3]))
	printCOFFHeader(info, info.FileHeader)
	printPEHeader(info, info.OptionalHeader)
	printSectionHeaders(info, info.Sections)
	print("=====================")
end


local function main()
	local mfile = mmap(filename);
	if not mfile then 
		print("Error trying to map: ", filename)
	end

	local bs = binstream(mfile:getPointer(), mfile.size, 0, true);
	local info, err = peparser:fromStream(bs);

	if not info then
		print("ERROR: fromStream - ", err)
		return
	end

	printDOSInfo(info.DOS)
	--printPEInfo(info.PE)

	--printCOFFHeader(info.PE, info.PE.COFFHeader)
	--printPEHeader(info.PE, info.PE.OptionalHeader)
	--printDataDirectories(info.PE, info.PE.OptionalHeader.Directory)
	--printSectionHeaders(info.PE, info.PE.Sections)
	--printImports(info)
	printExports(info)
	--printResources(info)
end

main()