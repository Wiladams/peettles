This directory contains test files that work directly against the working files in the peettles directory.  Each test begins the ```package.path = package.path..";../?.lua"``` so that importing a module is done in the same way that any other application would do it once peettles is installed into the Lua distribution: 'local peinfo = require("peettles.peparser")`


