This directory contains test files that work directly against the working files in the peettles directory.  Each test begins the ```package.path = package.path..";../?.lua"``` so that importing a module is done in the same way that any other application would do it once peettles is installed into the Lua distribution: 
```local peinfo = require("peettles.peparser")```

Ready made tools

* test_demangler.lua - Try out demangling C++ 'mangled' names.


Disassemblers

* http://ragestorm.net/distorm/

Dissasembly Documentation

* https://www.swansontec.com/sregisters.html
* http://www.mathemainzel.info/files/x86asmref.html
* http://ref.x86asm.net/coder32.html
* http://ref.x86asm.net/index.html

Tutorial 

* http://www.yashks.com/download/opcode.pdf