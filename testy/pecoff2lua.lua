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

local function printDOSInfo(pecoff)
    local info = pecoff.DOS;

	print("DOS = {")
	print(string.format("    Magic = '%c%c';", info.DOSHeader.e_magic[0], info.DOSHeader.e_magic[1]))
	print(string.format(" PEOffset = 0x%04X;", info.DOSHeader.e_lfanew));
	print(string.format(" StubSize = 0x%04x;", info.DOSStubSize))
	-- print the stub in base64
	--printData(info.DOSStub, info.DOSStubSize);
	print("};")
end

local function printCOFF(reader)
	local info = reader.COFF;

	print("COFF  = {")
    print(string.format("                Machine = 0x%X; ", info.Machine));      -- peenums.MachineType[info.Machine]);
	print(string.format("     NumberOfSections = %d;", info.NumberOfSections));
	print(string.format("        TimeDateStamp = 0x%X;", info.TimeDateStamp));
	print(string.format("PointerToSymbolTable = 0x%X;", info.PointerToSymbolTable));
	print(string.format("      NumberOfSymbols = %d;", info.NumberOfSymbols));
	print(string.format("SizeOfOptionalHeader = %d;", info.SizeOfOptionalHeader));
	print(string.format("        Characteristics: 0x%04X;", info.Characteristics));  -- enum.bitValues(peenums.Characteristics, info.Characteristics, 32)));
	print("};")
end

local function printDataDirectory(reader)
	local dirs = reader.PEHeader.Directories
	print("Directories = {")
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
		print(string.format("    %22s = {VirtualAddress = 0x%08X,  Size= 0x%08X,  Section='%s'};",  name, vaddr, dir.Size, sectionName))
	end
	print("};")
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

	printDOSInfo(info)
	printCOFF(info)
	--printOptionalHeader(info)
	printDataDirectory(info)
	--printSectionHeaders(info)
	--printImports(info)
	--printExports(info)
	--printResources(info)
end

main()