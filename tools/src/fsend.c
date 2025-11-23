#include <libftdi1/ftdi.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

void errchk (struct ftdi_context* ftdi, int ret) {
  if (ret<0) {
    printf("err: %s\n",ftdi_get_error_string(ftdi));
    exit(1);
  }
}
int main (int argc, char** argv) {
  int ret;
  if (argc>=2) {
    int dlen=strlen(argv[1]);
    if (!strncmp("0x",argv[1],2) || !strncmp("0X",argv[1],2)) {dlen=dlen-2;argv[1]=&argv[1][2];};
    unsigned int len=dlen/2+(dlen&1);
    unsigned char data [len]={};
    if (dlen&1) {
      for (int i=dlen;i>=2;i=i-2)
        sscanf(&argv[1][i-2],"%02hhx",&data[len-i/2-1]);
      sscanf(&argv[1][0],"%1hhx",&data[dlen/2]);
    }
    else
      for (int i=dlen;i>=2;i=i-2) 
        sscanf(&argv[1][i-2],"%02hhx",&data[len-i/2]);

    struct ftdi_context* ftdi;
    if (!(ftdi=ftdi_new())) {
      fprintf(stderr,"Failed to init FTDI\n");
      ftdi_free(ftdi);
    }
    errchk(ftdi,ftdi_usb_open(ftdi,0x403,0x6010));
    errchk(ftdi,ftdi_set_interface(ftdi,INTERFACE_B));
    errchk(ftdi,ftdi_set_baudrate(ftdi,115200));
    errchk(ftdi,ftdi_set_line_property(ftdi,BITS_8,STOP_BIT_1,NONE));

    //printf("buffer: ");
    //for (int i=0;i<len;i++) printf("%02x ",data[i]);
    //printf("\n");
    ret=ftdi_write_data(ftdi,data,len);
    if (argc<3 || argv[2][0]!='n') 
      printf("write return: %d\n",ret);
    if (ret==len) return 0;
    else return 1;
  }
  else {
    printf("usage: %s {DATA}\nDATA is a hex numeral containing the data to be sent, may be of any size\n",argv[0]);
    return 1;
  }

}
