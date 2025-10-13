#include <fcntl.h>
#include <stddef.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>

#include <libftdi1/ftdi.h>

//#include <pthread.h>

void errchk (struct ftdi_context* ftdi, int ret) {
  if (ret<0) {
    printf("error: %s\n",ftdi_get_error_string(ftdi));
    ftdi_usb_close(ftdi);
    ftdi_free(ftdi);
    exit(1);
  }
}
//int listen (void* arg) {
  //unsigned char dbuff [8];
  //struct ftdi_context* ftdi=arg;
  //while (ftdi_read_data(ftdi,dbuff,1)==0)
  //  usleep(1e3);
  //printf("\nreceived: ");
  //int rcvd=1;
  //printf("%02x ",dbuff[0]);
  //while (ftdi_read_data(ftdi,dbuff,1)==1) {
  //  rcvd++;
  //  printf("%02x ",dbuff[0]);
  //}
  //printf("\nlen: %d\n",rcvd);
  //return 0;
//}
int main (int argc, char** argv) {
  if (argc==1) {
    printf("Usage: %s [prog]\n\tWill send [prog] (a riscv32 executable) to the FPGA for execution\n",argv[0]);
    return 0;
  }
  int ret;

  struct ftdi_context* ftdi;
  if ( !(ftdi=ftdi_new()) ) {
    printf("error initializing ftdi library\n");
    return 1;
  }
  errchk(ftdi,ftdi_usb_open(ftdi,0x0403,0x6010)); //FT2232HL
  errchk(ftdi,ftdi_set_interface(ftdi,INTERFACE_B));
  errchk(ftdi,ftdi_set_baudrate(ftdi,115200));
  errchk(ftdi,ftdi_set_line_property(ftdi,BITS_8,STOP_BIT_1,NONE));

  //pthread_attr_t attr;
  //ret=pthread_attr_init(&attr);
  //pthread_t tid;
  //void* arg=ftdi;
  //pthread_create(&tid,&attr,(void*)&listen,arg);
  //ret=pthread_attr_destroy(&attr);
  
  //void** t_ret=malloc(8);
  //pthread_join(tid,t_ret);
  //printf("%d\n",*((int*)t_ret));

  int txt_fd=open(argv[1],O_RDONLY);
  if (txt_fd==-1) {
    printf("could not open file for reading\n");
    return 1;
  }
  unsigned char dbuff [256];
  //lseek(txt_fd,0x40,SEEK_SET); // for riscv64 binaries
  lseek(txt_fd,0x34,SEEK_SET);
  uint i;
  for (i=0;i<256;i++) {
    if ((i&3)==3) {
      read(txt_fd,&dbuff[i-3],4);
      //printf("%02x ",dbuff[i]);
      int last_word=(dbuff[i-3]|(dbuff[i-2]<<8)|(dbuff[i-1]<<16)|(dbuff[i]<<24));
      //printf("0x%08x\n",last_word);
      if (last_word == 0x00004b41 )
        break;
    }
  }
  i=i-3;
  printf("%u\n",i);
  ret=close(txt_fd);
  unsigned long cmd=1|(i<<21);
  printf("cmd: 0x%010lx\n",cmd);
  ret=ftdi_write_data(ftdi,(unsigned char*)&cmd,5);
  printf("write ret: %d\n",ret);
  ret=ftdi_write_data(ftdi,dbuff,i);
  printf("write ret: %d\n",ret);
  if (argc<=2) {
  unsigned char exe=0x03;
  ret=ftdi_write_data(ftdi,&exe,1);
  printf("write ret: %d\n",ret);
  }
  //ssize_t size=read(txt_fd,dbuff,8);
  //for (int i=0;i<8;i++) printf("%02x ",dbuff[i]);


  //printf("sending in 1 second\n");
  //usleep(1e6);
  //dbuff[0]=0x13;
  //ret=ftdi_write_data(ftdi,dbuff,1);
  //printf("write ret: %d\n",ret);

  void* listen_return;
  //pthread_join(tid,&listen_return);

  ftdi_usb_close(ftdi);
  ftdi_free(ftdi);
}
