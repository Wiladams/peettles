package.path = "../?.lua;"..package.path

local ffi = require("ffi")
local bit = require("bit")


local enum = require("peettles.enum")
local peenums = require("peettles.penums")
local mmap = require("peettles.mmap_win32")
local binstream = require("peettles.binstream")
local putils = require("peettles.print_utils")
local parse_COFF = require("peettles.parse_COFF")

local StorageClass = peenums.SymStorageClass;


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

local function printSectionHeaders(sections)
    if not sections then
        return;
    end

	print("  Sections = {")
	for idx,section in ipairs(sections) do
        print(string.format("    ['%d'] = {", idx));
        print(string.format("                    Name = '%s';",section.Name))
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

local function printSymbolTable(SymbolTable)
    print("  SymbolTable = {")
    for idx, res in ipairs(SymbolTable) do
        print("    Symbol = {")
        print(string.format("      SymbolIndex = %d;", res.SymbolIndex));
        print(string.format("      Name = '%s';", res.Name));
        print(string.format("      Value = 0x%X;", res.Value));
        print(string.format("      SectionNumber = %d;", res.SectionNumber));
        print(string.format("      Base Type = %d;", res.BaseType));
        print(string.format("      ComplexType = %d;", res.ComplexType));
        --print(string.format("  Type = 0x%X", res.Type));
        --print(string.format("      StorageClass = %d;",res.StorageClass));
        print(string.format("      StorageClass = '%s';", StorageClass[res.StorageClass]))
        print(string.format("      NumberOfAuxSymbols = %d;", res.NumberOfAuxSymbols));
        print("    };")
    end
    print("  };")
end

local function printStringTable(StringTable)
    if not StringTable then return false; end
    
    print("  StringTable = {")
    for idx, str in ipairs(StringTable) do
        print(string.format("    '%s';", str))
    end
    print("  };")
end


local function printCOFF(info)
	print("    COFF  = {")
    print(string.format("                 Machine = 0x%X; ", info.Machine));      -- peenums.MachineType[info.Machine]);
	print(string.format("        NumberOfSections = 0x%04X;", info.NumberOfSections));
	print(string.format("           TimeDateStamp = 0x%X;", info.TimeDateStamp));
	print(string.format("    PointerToSymbolTable = 0x%X;", info.PointerToSymbolTable));
	print(string.format("         NumberOfSymbols = %d;", info.NumberOfSymbols));
	print(string.format("    SizeOfOptionalHeader = %d;", info.SizeOfOptionalHeader));
	print(string.format("         Characteristics = 0x%04X;", info.Characteristics));  -- enum.bitValues(peenums.Characteristics, info.Characteristics, 32)));

    printSectionHeaders(info.Sections);
    printSymbolTable(info.SymbolTable);
    printStringTable(info.StringTable);
    print("  };")
end


local function main()
	local mfile = mmap(filename);
	if not mfile then 
		print("Error trying to map: ", filename)
	end

    local bs = binstream(mfile:getPointer(), mfile.size, 0, true)

	local info, err = parse_COFF(bs);
	if not info then
		print("ERROR: fromData - ", err)
		return
	end

    printCOFF(info);

end

main()