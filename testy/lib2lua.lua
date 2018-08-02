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

local function printCOFF(info)
	print("  COFF  = {")
    print(string.format("                 Machine = 0x%X; ", info.Machine));      -- peenums.MachineType[info.Machine]);
	print(string.format("        NumberOfSections = %d;", info.NumberOfSections));
	print(string.format("           TimeDateStamp = 0x%X;", info.TimeDateStamp));
	print(string.format("    PointerToSymbolTable = 0x%X;", info.PointerToSymbolTable));
	print(string.format("         NumberOfSymbols = %d;", info.NumberOfSymbols));
	print(string.format("    SizeOfOptionalHeader = %d;", info.SizeOfOptionalHeader));
	print(string.format("         Characteristics = 0x%04X;", info.Characteristics));  -- enum.bitValues(peenums.Characteristics, info.Characteristics, 32)));
	print("  };")
end

    -- [16] file identifier
    -- [12] file modification timestamp
    -- [6] owner ID
    -- [6] group ID
    -- [8] file mode
    -- [10] file size in bytes
    -- [2]  end char
    -- [4]  version
local function printArchiveMember(member)
    print(string.format("  ['%s'] = {", member.Identifier))
    print(string.format("    HeaderOffset = 0x%x", member.HeaderOffset))
    print(string.format("    DateTime = '%s'", member.DateTime))
    print(string.format("    OwnerID = '%s'", member.OwnerID));
    print(string.format("    GroupID = '%s'", member.OwnerID));
    print(string.format("    Size = %s", string.format("0x%x",member.Size)));
    print("    Data = [=[")
    --printData(member.Data, member.Size)
    print("    ]=];")
    print(string.format("  };"))
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
    for idx, member in ipairs(info.Members) do
        printArchiveMember(member)
    end
	print("};")
end

main()