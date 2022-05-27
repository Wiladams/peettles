local FileSystemItem = require("FileSystemItem");

local FileSystem = {}
setmetatable(FileSystem, {
	__call = function(self, ...)
		return self:create(...);
	end,
});

local FileSystem_mt = {
	__index = FileSystem;
}

function FileSystem.init(self, basepath, filter)
	local obj = {
		RootItem = FileSystemItem({
			BasePath = basepath,
			Filter = filter});
	};
	setmetatable(obj, FileSystem_mt);

	return obj;
end

function FileSystem.create(self, basepath, filter)
	return self:init(basepath, filter);
end

function FileSystem.getItem(self, pattern)
	for item in self.RootItem:items(pattern) do
		return item;
	end

	return nil;
end

function FileSystem.getItems(self, pattern)
	return self.RootItem:items(pattern);
end

return FileSystem;
