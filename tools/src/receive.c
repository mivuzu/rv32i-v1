#include <libftdi1/ftdi.h>
#include <stdio.h>
//#include <stdlib.h>
#include <unistd.h>
#include <time.h>
#include <pthread.h>
#include <termios.h>

int err_sig=0;

void disable_line_buffering (struct termios* term0) {
  tcgetattr(STDIN_FILENO,term0);
  struct termios term1;
  term1=*term0;
  term1.c_lflag&=~(ICANON|ECHO);
  tcsetattr(STDIN_FILENO,TCSANOW,&term1);
}

void restore_terminal (struct termios* term0) {
  tcsetattr(STDIN_FILENO,TCSANOW,term0);
}

void monitor (void** args) {
  struct termios* term0=(struct termios*)args[0];
  int* quit_sig=(int*)args[1];
  char in;
  while (!*quit_sig) {
    in=getchar();
    if (in=='q' || err_sig) *quit_sig=1;
    usleep(1e4);
  }
  restore_terminal(term0);
}

void ftdi_close (struct ftdi_context* ftdi) {
  ftdi_usb_close(ftdi);
  ftdi_free(ftdi);
}

void ftdi_errchk(struct ftdi_context* ftdi, int ret) {
  if (ret<0 && !err_sig) {
    printf("FTDI error: %s\npress any key to end...\n",ftdi_get_error_string(ftdi));
    err_sig=1;
  }
}

int main (int argc, char** argv) {
  struct termios term0={};
  disable_line_buffering(&term0);
  //monitor thread
  pthread_t th_monitor;
  int quit_sig=0;
  void* args [2]={&term0,&quit_sig};
  pthread_create(&th_monitor,NULL,(void*)monitor,(void*)args);
    
  struct ftdi_context* ftdi;
  if (!(ftdi=ftdi_new())) {
    fprintf(stderr,"Failed to init FTDI\n");
    return 1;
  }
  ftdi_errchk(ftdi,ftdi_usb_open(ftdi,0x403,0x6010));
  ftdi_errchk(ftdi,ftdi_set_interface(ftdi,INTERFACE_B));
  ftdi_errchk(ftdi,ftdi_set_baudrate(ftdi,115200));
  ftdi_errchk(ftdi,ftdi_set_line_property(ftdi,BITS_8,STOP_BIT_1,NONE));

  unsigned char pk [16]={};
  int ret=0;
  if (argc>1) {
    quit_sig=1;
    pthread_cancel(th_monitor);
    restore_terminal(&term0);
    ret=ftdi_read_data(ftdi,&pk[0],16);
    if (ret>0) {
      struct timespec now;
      clock_gettime(CLOCK_MONOTONIC,&now);
      printf("%ld.%9ld: (%2d) ",now.tv_sec,now.tv_nsec,ret);
      for (int i=0;i<ret;i++) printf("%2d: 0x%02x  ",i,pk[i]);
      printf("\n");
    }
  }
  else while (!quit_sig) {
    ret=ftdi_read_data(ftdi,&pk[0],16);
    if (ret>0) {
      struct timespec now;
      clock_gettime(CLOCK_MONOTONIC,&now);
      printf("%ld.%9ld: (%2d) ",now.tv_sec,now.tv_nsec,ret);
      for (int i=0;i<ret;i++) printf("%2d: 0x%02x  ",i,pk[i]);
      printf("\n");
    }
    usleep(5*(1e3));
  }
  printf("\n");
  pthread_join(th_monitor,NULL);
  ftdi_close(ftdi);
}
