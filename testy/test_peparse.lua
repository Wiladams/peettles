package.path = "../?.lua;"..package.path

local ffi = require("ffi")
local bit = require("bit")

local enum = require("peettles.enum")
local peinfo = require("peettles.peparser")
local peenums = require("peettles.penums")
local mmap = require("peettles.mmap_win32")
local binstream = require("peettles.binstream")
local putils = require("peettles.print_utils")


local filename = arg[1];

if not filename then
	print("NO FILE SPECIFIED")
    return
end


local function printDOSInfo(info)
	print("==== DOS ====")
	print("    Magic: ", string.format("%c%c", info.Header.e_magic[0], info.Header.e_magic[1]))
	print("PE Offset: ", string.format("0x%04x", info.Header.e_lfanew));
	print("Stub Size: ", string.format("0x%04x (%d)", info.StubSize, info.StubSize))
	print("---------------------")
end

local function printCOFF(reader)
	local info = reader.COFF;

	print("==== COFF ====")
	print("                Machine: ", string.format("0x%X", info.Machine), peenums.MachineType[info.Machine]);
	print("     Number Of Sections: ", info.NumberOfSections);
	print("        Time Date Stamp: ", string.format("0x%X", info.TimeDateStamp));
	print("Pointer To Symbol Table: ", info.PointerToSymbolTable);
	print("      Number of Symbols: ", info.NumberOfSymbols);
	print("Size of Optional Header: ", info.SizeOfOptionalHeader);
	print(string.format("        Characteristics: 0x%04x  (%s)", info.Characteristics,
		enum.bitValues(peenums.Characteristics, info.Characteristics, 32)));
	print("---------------------")
end

--[[
    print("==== readPE32PlusHeader ====")


    print("      Size of Image: ", self.PEHeader.SizeOfImage)
    print("    Size of Headers: ", self.PEHeader.SizeOfHeaders)
    print("       Loader Flags: ", self.PEHeader.LoaderFlags)

--]]

local function printOptionalHeader(browser)
	local info = browser.PEHeader
	print("==== Optional Header ====")
	
	if not info then
		print(" **   NONE  **")
		return 
	end


	print("                   Magic: ", string.format("0x%04X",info.Magic))
    print("          Linker Version: ", string.format("%d.%d",info.MajorLinkerVersion, info.MinorLinkerVersion));
	print("            Size Of Code: ", string.format("0x%08x", info.SizeOfCode))
    print("              Image Base: ", info.ImageBase)
    print("       Section Alignment: ", info.SectionAlignment)
	print("          File Alignment: ", info.FileAlignment)
	print("  Address of Entry Point: ", string.format("0x%08X",info.AddressOfEntryPoint))
	print(string.format("            Base of Code: 0x%08X", info.BaseOfCode))
	-- BaseOfData only exists for 32-bit, not 64-bit
	if info.BaseOfData then
		print(string.format("            Base of Data: 0x%08X", info.BaseOfData))
	end

	print(string.format("Number of Rvas and Sizes: 0x%08X (%d)", info.NumberOfRvaAndSizes, info.NumberOfRvaAndSizes))
	print("---------------------")
end

local function printDataDirectory(reader, dirs)
	local dirs = reader.PEHeader.Directories
	print("==== Directory Entries ====")
	print(string.format("%20s   %10s    %12s  %s",
		"name", "location", "size (bytes)", "section"))
	for name,dir in pairs(dirs) do
		--print(name, dir)
		local vaddr = dir.VirtualAddress
		local sectionName = "UNKNOWN"
		if vaddr > 0 then
			local sec = reader:GetEnclosingSectionHeader(vaddr)
			if sec then
				sectionName = sec.Name
			end
		end
		print(string.format("%20s   0x%08X    %12s   %s", 
			name, vaddr, string.format("0x%x (%d)", dir.Size, dir.Size), sectionName))
	end
	print("---------------------")
end

local function printSectionHeaders(reader)
	print("===== SECTIONS =====")
	for name,section in pairs(reader.Sections) do
		print("Name: ", name)
		print(string.format("            Virtual Size: %d", section.VirtualSize))
		print(string.format("         Virtual Address: 0x%08X", section.VirtualAddress))
		print(string.format("        Size of Raw Data: 0x%08X (%d)", section.SizeOfRawData, section.SizeOfRawData))
		print(string.format("     Pointer to Raw Data: 0x%08X", section.PointerToRawData))
		print(string.format("  Pointer to Relocations: 0x%08X", section.PointerToRelocations))
		print(string.format("  Pointer To Linenumbers: 0x%08X", section.PointerToLinenumbers))
		print(string.format("   Number of Relocations: %d", section.NumberOfRelocations))
		print(string.format("  Number of Line Numbers: %d", section.NumberOfLinenumbers))
		print(string.format("         Characteristics: 0x%08X  (%s)", section.Characteristics, 
			enum.bitValues(peenums.SectionCharacteristics, section.Characteristics)))
	end
	print("---------------------")
end

local function printImports(reader)
	print("===== IMPORTS =====")
	if not reader.Import then return false, "No Imports"; end

	for k,v in pairs(reader.Import) do
		print(k)
		for i, name in ipairs(v) do
			print(string.format("    %s",name))
		end
	end
	print("---------------------")
end

local function printExports(reader)
	print("===== EXPORTS =====")
	if (not reader.Export) then
		print("  NO EXPORTS")
		return ;
	end

	local res = reader.Export




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
	for k,v in pairs(reader.Export.OrdinalOnly) do
		if type(v) == "string" then
			print(k, v)
		else
			print (k, string.format("0x%x", v))
		end
	end

	print(" = Named Functions =")
	for i, entry in ipairs(reader.Export.NamedFunctions) do
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
	if not info.Resources then
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
		
		-- It is Microsoft convention to used the 
        -- first three levels to indicate: resource type, ID, language ID
        if subdir.level == 1 then
			printDebug(level, "    Entry ID (KIND): ", subdir.Kind, peenums.ResourceTypes[subdir.Kind])
        elseif subdir.level == 2 then
			printDebug(level, "    Entry ID (NAME): ", subdir.ItemID)
        elseif subdir.level == 3 then
			printDebug(level, "Entry ID (LANGUAGE): ", subdir.LanguageID)
		end

		printDebug(level, "Characteristics: ", subdir.Characteristics);
		printDebug(level, "Time Date Stamp: ", subdir.TimeDateStamp);
		printDebug(level, "        Version: ", string.format("%d.%02d", subdir.MajorVersion, info.Resources.MinorVersion));
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

	printDirectory(info.Resources)
end


local function main()
	local mfile = mmap(filename);
	if not mfile then 
		print("Error trying to map: ", filename)
	end

	local info, err = peinfo:fromData(mfile:getPointer(), mfile.size);
	if not info then
		print("ERROR: fromData - ", err)
		return
	end

	printDOSInfo(info.DOS)
	printCOFF(info)
	printOptionalHeader(info)
	printDataDirectory(info)
	printSectionHeaders(info)
	printImports(info)
	printExports(info)
	printResources(info)
end

main()