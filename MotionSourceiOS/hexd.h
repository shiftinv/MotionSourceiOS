#ifndef _hexd_h
#define _hexd_h

static void hexd(NSData* data) {return;
    uint64_t len = [data length];
    const unsigned char *buf = [data bytes];
    for (int i=0; i<len; i+=16) {
        printf("%06x: ", i);
        for (int j=0; j<16; j++)
            if (i+j < len)
                printf("%02x ", buf[i+j]);
            else
                printf("   ");
        printf(" ");
        for (int j=0; j<16; j++)
            if (i+j < len)
                printf("%c", isprint(buf[i+j]) ? buf[i+j] : '.');
        printf("\n");
    }
    printf("\n");
}

#endif
