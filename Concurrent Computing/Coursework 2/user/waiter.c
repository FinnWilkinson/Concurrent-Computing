/* Copyright (C) 2017 Daniel Page <csdsp@bristol.ac.uk>
 *
 * Use of this source code is restricted per the CC BY-NC-ND license, a copy of
 * which can be found via http://creativecommons.org (and should be included as
 * LICENSE.txt within the associated archive or repository).
 */

#include "waiter.h"

extern void main_philosopher();
pid_t myID;


void main_waiter() {
  int forks = 15;
  pid_t first;
  myID = find();
  for (int i = 0; i < 16; i++) {
    pid_t pid = fork();
    if(i==0) first = pid;
    if(0 != pid){
      create(myID, pid); //create all channels, one to each philosopher
    }
    if( 0 == pid ) {
      exec( &main_philosopher );
    }
  }
  write( STDOUT_FILENO, "waiter done", 11 );
  channel_status_t chanStat;
  channel_message_t chanMess;
  while(1){
    for (int i = 0; i < 16; i++) {
      chanStat = check_status(i+1);
      if(chanStat == REQUEST){
        chanMess = check_message(i+1);
        if(chanMess == REQUEST_FORK){
          if(forks > 1){
            forks = forks - 2;
            write( STDOUT_FILENO, "forks given ", 12 );
            send(GIVE_FORK, i+1, REPLY);
          }
          else{
            send(DENY_FORK, i+1, REPLY);
            write( STDOUT_FILENO, "forks denied ", 13 );
          }
        }
        else if(chanMess == RETURN_FORK){
          forks = forks + 2;
        }
      }
    }
  }


  exit( EXIT_SUCCESS );
}
