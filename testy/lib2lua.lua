package.path = "../?.lua;"..package.path

local ffi = require("ffi")
local bit = require("bit")


local enum = require("peettles.enum")
local libinfo = require("peettles.libparser")
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

local function printSectionHeaders(sections)

	print("  Sections = {")
	for name,section in pairs(sections) do
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


local function printCOFF(info)
	print("    COFF  = {")
    print(string.format("                 Machine = 0x%X; ", info.Machine));      -- peenums.MachineType[info.Machine]);
	print(string.format("        NumberOfSections = %d;", info.NumberOfSections));
	print(string.format("           TimeDateStamp = 0x%X;", info.TimeDateStamp));
	print(string.format("    PointerToSymbolTable = 0x%X;", info.PointerToSymbolTable));
	print(string.format("         NumberOfSymbols = %d;", info.NumberOfSymbols));
	print(string.format("    SizeOfOptionalHeader = %d;", info.SizeOfOptionalHeader));
	print(string.format("         Characteristics = 0x%04X;", info.Characteristics));  -- enum.bitValues(peenums.Characteristics, info.Characteristics, 32)));

    printSectionHeaders(info.Sections)
    print("    };")
end

    -- [16] file identifier
    -- [12] file modification timestamp
    -- [6] owner ID
    -- [6] group ID
    -- [8] file mode
    -- [10] file size in bytes
    -- [2]  end char

local function printArchiveMember(member)
    print(string.format("  ['%s'] = {", member.Identifier))
    print(string.format("    HeaderOffset = 0x%x", member.HeaderOffset))
    print(string.format("    DateTime = '%s'", member.DateTime))
    print(string.format("    OwnerID = '%s'", member.OwnerID));
    print(string.format("    GroupID = '%s'", member.OwnerID));
    print(string.format("    Size = %s", string.format("0x%x",member.Size)));
    printCOFF(member)
    print(string.format("  };"))
end

local function printFirstLinkMember(member)
    --printArchiveMember(member);
    print(string.format("  FirstLinkMember = {"));
    print(string.format("       Identifier = '%s';", member.Identifier))
    print(string.format("     HeaderOffset = 0x%x", member.HeaderOffset))
    print(string.format("         DateTime = '%s'", member.DateTime))
    print(string.format("          OwnerID = '%s'", member.OwnerID));
    print(string.format("          GroupID = '%s'", member.OwnerID));
    print(string.format("             Size = %s", string.format("0x%x",member.Size)));
    print(string.format("  NumberOfSymbols = %d;", member.NumberOfSymbols))
    print(string.format("          Symbols = {"))
    for idx=1, member.NumberOfSymbols do
        print(string.format("            {0x%4x, '%s'};", member.Offsets[idx], member.Symbols[idx]))
    end
    print("  };")
end

local function printSecondLinkMember(member)
    --printArchiveMember(member);
    print(string.format("  SecondLinkMember = {"));
    print(string.format("        Identifier = '%s';", member.Identifier))
    print(string.format("      HeaderOffset = 0x%x", member.HeaderOffset))
    print(string.format("          DateTime = '%s'", member.DateTime))
    print(string.format("           OwnerID = '%s'", member.OwnerID));
    print(string.format("           GroupID = '%s'", member.OwnerID));
    print(string.format("              Size = %s", string.format("0x%x",member.Size)));
    print(string.format("   NumberOfMembers = %d;", member.NumberOfMembers))
    print(string.format("    MemberOffsets = {"))
    for counter=1, member.NumberOfMembers do 
        print(string.format("      0x%4x;", member.MemberOffsets[counter]))
    end
    print("    };")
    print(string.format("  Symbols = {"))
    for idx=1, member.NumberOfSymbols do
        print(string.format("    {index= 0x%04x, offset = 0x%04X, '%s'};", member.Indices[idx], member.MemberOffsets[member.Indices[idx]], member.Symbols[idx]))
    end
    print("    };")
    print("  };")
end


local function main()
	local mfile = mmap(filename);
	if not mfile then 
		print("Error trying to map: ", filename)
	end

	local info, err = libinfo:fromData(mfile:getPointer(), mfile.size);
	if not info then
		print("ERROR: fromData - ", err)
		return
	end

	print(string.format("local lib = { "))
    print(string.format("  Signature = '%s';", info.Signature))
---[[
    printFirstLinkMember(info.FirstLinkMember)
    printSecondLinkMember(info.SecondLinkMember)
    for idx, member in ipairs(info.Members) do
        printArchiveMember(member)
    end
--]]
	print("};")
end

main()