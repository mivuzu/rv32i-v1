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
  if (argc>=3) {
    unsigned int len;
    ret=sscanf(argv[1],"%u",&len);
    if (!ret||len>256) exit(1);
    if (strlen(argv[2]) < len*2) exit(1);
    unsigned char data [len];
    for (int i=0;i<len;i++) {
      ret=sscanf(&argv[2][len*2-i*2-2],"%02x",(int*)&data[i]);
      if (!ret) exit(1);
    }

    struct ftdi_context* ftdi;
    if (!(ftdi=ftdi_new())) {
      fprintf(stderr,"Failed to init FTDI\n");
      ftdi_free(ftdi);
    }
    errchk(ftdi,ftdi_usb_open(ftdi,0x403,0x6010));
    errchk(ftdi,ftdi_set_interface(ftdi,INTERFACE_B));
    errchk(ftdi,ftdi_set_baudrate(ftdi,115200));
    errchk(ftdi,ftdi_set_line_property(ftdi,BITS_8,STOP_BIT_1,NONE));

    ret=ftdi_write_data(ftdi,data,len);
    if (argc<4 || argv[3][0]!='n') printf("%d\n",ret);
    if (ret==len) return 0;
    else return 1;
  }
  else {
    printf("usage: %s [LEN] [DATA]\nLEN is taken as an unsigned integer, the transfer size in bytes. DATA is the actual data, formatted as a single hex numeral\n",argv[0]);
    return 1;
  }

}
