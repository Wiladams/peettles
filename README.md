# peettles
LuaJIT tools for handling Portable Executable files

This project supercedes [LJITPEReader]https://github.com/Wiladams/LJITPEReader

Pronunciation: P-E Tools, or 'pea tools'

In general, parsing, extracting, reconstructing and generally handling Portable Executable files

*Loading a PE file*

1. Extract from the header the entry point, heap and stack sizes. 
2. Iterate through each section and copy it from the file into virtual memory (although not required, it is good to clear the difference between the section size in memory and in the file to 0). 
3. Find the address of the entry point by finding the correct entry in the symbol table. 
4. Create a new thread at that address and begin executing! 
To load a PE file that requires a dynamic DLL you can do the same, but check the Import Table (referred to by the data directory) to find what symbols and PE files are required, the Export Table (also referred to by the data directory) inside of that PE file to see where those symbols are and match them up once you've loaded that PE's sections into memory (and relocated them!) And lastly, beware that you'll have to recursively resolve each DLL's Import Tables as well, and some DLLs can use tricks to reference a symbol in the DLL loading it so make sure you don't get your loader stuck in a loop! Registering symbols loaded and making them global might be a good solution. 
It may also be a good idea to check the Machine and Magic fields for validity, not just the PE signature. This way your loader won't try loading a 64 bit binary into 32 bit mode (this would be certain to cause an exception). 
64 bit PE
64 bit PE's are extremely similar to normal PE's, but the machine type, if AMD64, is 0x8664, not 0x14c. This field is directly after the PE signature. The magic number also changes from 0x10b to 0x20b. The magic field is at the beginning of the optional header. 
Also several fields have been expanded to 64 bits (but not RVAs or offsets). An example of these is the Preffered Base Address 


Microsoft Documentation

* https://msdn.microsoft.com/library/windows/desktop/ms680547(v=vs.85).aspx
* https://msdn.microsoft.com/en-us/library/ms809762.aspx

Sysinternals

https://docs.microsoft.com/en-us/sysinternals/


Other Stuff

* http://net.pku.edu.cn/~course/cs201/2003/mirrorWebster.cs.ucr.edu/Page_TechDocs/pe.txt
* http://www.sunshine2k.de/reversing/tuts/tut_rvait.htm
* http://www.osdever.net/documents/PECOFF.pdf
* http://www.pelib.com/resources/kath.txt
* https://resources.infosecinstitute.com/complete-tour-of-pe-and-elf-part-1/#article
* http://www.delphibasics.info/home/delphibasicsarticles/anin-depthlookintothewin32portableexecutablefileformat-part2

Crash Dumps

https://code.google.com/archive/p/volatility/wikis/CrashAddressSpace.wiki

Pretty Pictures

http://www.openrce.org/reference_library/files/reference/PE%20Format.pdf


