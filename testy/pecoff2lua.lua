package.path = "../?.lua;"..package.path

local ffi = require("ffi")
local bit = require("bit")
local disasm = require("dis_x86")
local disasm64 = require("dis_x64")

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
local function disassemble(stub)
	local code = ffi.string(stub.Data, stub.Size)
	disasm.disass(code, stub.Offset, out);
end

local function printDOSInfo(pecoff)
    local info = pecoff.DOS;

	print("  DOS = {")
	print(string.format("                   Magic = '%c%c';", info.DOSHeader.e_magic[0], info.DOSHeader.e_magic[1]))
	print(string.format("                PEOffset = 0x%04X;", info.DOSHeader.e_lfanew));
	print(string.format("        HeaderParagraphs = %d", info.DOSHeader.e_cparhdr));
	print(string.format("            StreamOffset = 0x%04X", info.DOSHeader.StreamOffset));
	print(string.format("        HeaderSizeActual = 0x%04X;", info.DOSHeader.HeaderSizeActual));
	print(string.format("    HeaderSizeCalculated = 0x%04X;", info.DOSHeader.HeaderSizeCalculated));
	print("    Stub = {")
	print(string.format("            Offset = 0x%04X;", info.DOSStub.Offset))
	print(string.format("              Size = 0x%04x;", info.DOSStub.Size))
	print("              Code = [[")
	--disassemble(info.DOSStub);
	printData(info.DOSStub.Data, info.DOSStub.Size);
	print("]];");
	print("    };")
	-- print the stub in base64

	print("  };")
end

local function printCOFF(reader)
	local info = reader.COFF;

	print("  COFF  = {")
	print(string.format("               Signature ='%c%c';", info.Signature[0], info.Signature[1]))
    print(string.format("                 Machine = 0x%X; ", info.Machine));      -- peenums.MachineType[info.Machine]);
	print(string.format("        NumberOfSections = %d;", info.NumberOfSections));
	print(string.format("           TimeDateStamp = 0x%X;", info.TimeDateStamp));
	print(string.format("    PointerToSymbolTable = 0x%X;", info.PointerToSymbolTable));
	print(string.format("         NumberOfSymbols = %d;", info.NumberOfSymbols));
	print(string.format("    SizeOfOptionalHeader = %d;", info.SizeOfOptionalHeader));
	print(string.format("         Characteristics = 0x%04X;", info.Characteristics));  -- enum.bitValues(peenums.Characteristics, info.Characteristics, 32)));
	print("  };")
end

local function printOptionalHeader(peinfo)
	local info = peinfo.COFF.PEHeader

	if not info then
		return  false, "No Optional Header Info"
	end

	print("  OptionalHeader = {")
	print(string.format("                   Magic = 0x%04X;",info.Magic))
    print(string.format("           LinkerVersion = '%d.%02d';", info.MajorLinkerVersion, info.MinorLinkerVersion));
	print(string.format("              SizeOfCode = 0x%08X;", info.SizeOfCode))
    print(string.format("               ImageBase = 0x%sULL;", bit.tohex(info.ImageBase)))
    print(string.format("        SectionAlignment = %d;", info.SectionAlignment))
	print(string.format("           FileAlignment = %d;", info.FileAlignment))
	print(string.format("     AddressOfEntryPoint = 0x%08X;",info.AddressOfEntryPoint))
	print(string.format("              BaseOfCode = 0x%08X;", info.BaseOfCode))
	-- BaseOfData only exists for 32-bit, not 64-bit
	if info.BaseOfData then
		print(string.format("            BaseOfData = 0x%08X", info.BaseOfData))
	end
	print(string.format("               OSVersion = '%d.%02d'",	info.MajorOperatingSystemVersion,	info.MinorOperatingSystemVersion));
	print(string.format("    NumberOfRvasAndSizes = %d;", info.NumberOfRvaAndSizes))
	print("  };")
end


local function printSectionHeaders(reader)

	print("  Sections = {")
	for name,section in pairs(reader.COFF.Sections) do
		print(string.format("    ['%s'] = {", name))
		print(string.format("             VirtualSize = 0x%08X;", section.VirtualSize))
		print(string.format("          VirtualAddress = 0x%08X;", section.VirtualAddress))
		print(string.format("           SizeOfRawData = 0x%08X;", section.SizeOfRawData))
		print(string.format("        PointerToRawData = 0x%08X;", section.PointerToRawData))
		print(string.format("    PointerToRelocations = 0x%08X;", section.PointerToRelocations))
		print(string.format("    PointerToLinenumbers = 0x%08X;", section.PointerToLinenumbers))
		print(string.format("     NumberOfRelocations = %d;", section.NumberOfRelocations))
		print(string.format("     NumberOfLineNumbers = %d;", section.NumberOfLinenumbers))
		print(string.format("         Characteristics = 0x%08X;", section.Characteristics))
		print(  "    };")
	end
	print("  };")
end

local function printDataDirectory(reader)
	local dirs = reader.COFF.PEHeader.Directories
	if not dirs then return false end

	print("  Directories = {")
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
		--print(string.format("    %22s = {VirtualAddress = 0x%08X,  Size= 0x%08X,  Section='%s'};",  name, vaddr, dir.Size, sectionName))
		print(string.format("    %22s = {VirtualAddress = 0x%08X,  Size= 0x%08X,  Section='%s'};",  name, vaddr, dir.Size))
	end
	print("  };")
end

local function printImports(reader)
	if not reader.Imports then return false, "No Imports"; end

	print("Imports = {")
	for k,v in pairs(reader.Imports) do
		print(string.format("  ['%s'] = {", k))
		for i, name in ipairs(v) do
			print(string.format("    '%s',",name))
		end
		print("  };")
	end
	print("};")
end

local function printExports(reader)

	if (not reader.Exports) then
		return false, "  NO EXPORTS"
	end

	local res = reader.Exports

	print("  Exports = {")
	print(string.format("              ExportFlags = 0x%08X;", res.Characteristics))
	print(string.format("            TimeDateStamp = 0x%08X;", res.TimeDateStamp))
	print(string.format("                  Version = '%d.%02d';", res.MajorVersion, res.MinorVersion))
    print(string.format("                    nName = 0x%08X;", res.nName))
    print(string.format("               ModuleName = '%s';", res.ModuleName))
    print(string.format("              OrdinalBase = %d;", res.nBase))
    print(string.format("        NumberOfFunctions = %d;", res.NumberOfFunctions));
    print(string.format("            NumberOfNames = %d;", res.NumberOfNames));
    print(string.format("       AddressOfFunctions = 0x%08X;", res.AddressOfFunctions));
    print(string.format("           AddressOfNames = 0x%08X;", res.AddressOfNames));
    print(string.format("    AddressOfNameOrdinals = 0x%08X;", res.AddressOfNameOrdinals));

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

	print("    OrdinalOnly = {")
	for k,v in pairs(reader.Exports.OrdinalOnly) do
		if type(v) == "string" then
			print(k, v)
		else
			print (string.format("      [%d] = %s;", k, string.format("0x%x", v)))
		end
	end
	print("    };")

	print("    NamedFunctions = {")
	for i, entry in ipairs(reader.Exports.NamedFunctions) do
		if type(entry.funcptr) == "string" then
			print(string.format("      %s = {Hint = %d, Ordinal = %d, Forward = '%s'};",entry.name, entry.hint, entry.ordinal, entry.funcptr))
		else 
			print(string.format("      %s = {Hint = %d, Ordinal = %d, Address = 0x%08X};",entry.name, entry.hint, entry.ordinal, entry.funcptr))
		end
	end
	print("    };")

	print("  };")
end

local function printResources(peinfo)
	if not peinfo.Resources then
		return false, "No Resources";
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
		level = level or 0
		printDebug(level, "SUBDIRECTORY")
		printDebug(level, "          Level: ", subdir.level or "ROOT")
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
		printDebug(level, "        Version: ", string.format("%d.%02d", subdir.MajorVersion, subdir.MinorVersion));
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

	printDirectory(peinfo.Resources)
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

	print(string.format("local pecoff = { "))
	printDOSInfo(info)
	printCOFF(info)
	printOptionalHeader(info)
	printSectionHeaders(info)
	printDataDirectory(info)
	--printImports(info)
	--printExports(info)
	--printResources(info)
	print("};")
end

main()