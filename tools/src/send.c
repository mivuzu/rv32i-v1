#include <libftdi1/ftdi.h>
#include <pthread.h>
#include <termios.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>

int error_sig=0;

void disable_line_buffering (struct termios* term0, struct termios* term1) {
  tcgetattr(STDIN_FILENO, term0);
  *term1=*term0;
  (*term1).c_lflag&=~(ICANON|ECHO);
  tcsetattr(STDIN_FILENO,TCSANOW,term1);
}
void restore_terminal (struct termios* term0) {
  tcsetattr(STDIN_FILENO,TCSANOW,term0);
}

void monitor (void** args) {
  struct termios* term0=(struct termios*)args[0];
  int* send_sig=args[1];
  int* i_sig=args[2];
  int* quit_sig=args[3];

  char in=0;
  while (!(*quit_sig)) {
    in=getchar();
    if (error_sig || in=='q') *quit_sig=1;
    else if (in=='d') *send_sig=1;
    else if (in=='s') *i_sig=1;
    usleep(1e4);
  }
  restore_terminal(term0);
}

void get_byte(unsigned char* pk) {
  char in;
  char val[2]={};
  for (int i=0;i<2;i++) {
    in=getchar();
    if (in&0x10) val[i]=in-0x30;
    else if (in&0x40) val[i]=10+in-0x61;
  }
  *pk=val[0]*16+val[1];
}

void* main_exit (struct termios* term0, struct ftdi_context* ftdi, int* quit_sig) {
  restore_terminal(term0);
  ftdi_usb_close(ftdi);
  ftdi_free(ftdi);
  *quit_sig=1;
  return 0;
}

void ftdi_close (struct ftdi_context* ftdi) {
  ftdi_usb_close(ftdi);
  ftdi_free(ftdi);
}

void errchk (struct ftdi_context* ftdi, int ret) {
  if (ret<0 && !error_sig) {
    printf("FTDI error: %s\npress any key to end...\n",ftdi_get_error_string(ftdi));
    error_sig=1;
  }
}


int main (int argc, char** argv) {
  struct termios term0,term1;
  disable_line_buffering(&term0,&term1);

  pthread_t th_monitor;
  int send_sig=0;
  int i_sig=0;
  int quit_sig=0;
  void* args[4]={&term0,&send_sig,&i_sig,&quit_sig};
  pthread_create(&th_monitor,NULL,(void*)monitor,(void*)args);


  struct ftdi_context* ftdi;
  if (!(ftdi=ftdi_new())) {
    fprintf(stderr,"Failed to init FTDI\n");
    ftdi_free(ftdi);
    restore_terminal(&term0);
    quit_sig=1;
  }
  errchk(ftdi,ftdi_usb_open(ftdi,0x403,0x6010));
  errchk(ftdi,ftdi_set_interface(ftdi,INTERFACE_B));
  errchk(ftdi,ftdi_set_baudrate(ftdi,115200));
  errchk(ftdi,ftdi_set_line_property(ftdi,BITS_8,STOP_BIT_1,NONE));

  if (argc>=2) {
    unsigned long pk;
    restore_terminal(&term0);
    pk=strtol(argv[1],NULL,16);
    int ret=ftdi_write_data(ftdi,(unsigned char*)&pk,1);
    if (ret>0) printf("Sent 0x%02lx\n",pk);
    else exit(1);
    quit_sig=1;
    pthread_cancel(th_monitor);
  }
  else {
    int ret=0;
    unsigned char pk=0;
    while (!quit_sig) {
      if (send_sig) {
        send_sig=0;
        printf("enter 2-digit hex numeral... ");
        term1.c_lflag|=(ECHO);
        restore_terminal(&term1);
        get_byte(&pk);
        printf("\r\33[2K"); 
        disable_line_buffering(&term0,&term1);
        ret=ftdi_write_data(ftdi,&pk,1);
        if (ret>0) printf("Sent 0x%02x\n",pk);
        else exit(1);
      }
      else if (i_sig) {
        i_sig=0;
        pk++;
        ret=ftdi_write_data(ftdi,&pk,1);
        if (ret>0) printf("Sent 0x%x\n",pk);
        else exit(1);
      }
      usleep(5*(1e3));
    }
  }
  pthread_join(th_monitor,NULL);
  ftdi_close(ftdi);
  return 0;
}
