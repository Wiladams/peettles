local pecoff = { 
  DOS = {
                   Magic = 'MZ';
                PEOffset = 0x00F0;
        HeaderParagraphs = 4
            StreamOffset = 0x003E
        HeaderSizeActual = 0x003E;
    HeaderSizeCalculated = 0x0040;
    Stub = {
            Offset = 0x0040;
              Size = 0x00b0;
    };
  };
};
