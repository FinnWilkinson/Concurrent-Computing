/* Copyright (C) 2017 Daniel Page <csdsp@bristol.ac.uk>
 *
 * Use of this source code is restricted per the CC BY-NC-ND license, a copy of
 * which can be found via http://creativecommons.org (and should be included as
 * LICENSE.txt within the associated archive or repository).
 */

#include "philosopher.h"

my_status_t current_status;
int myID;
int myChan;
int forks;

void main_philosopher() {
    myID = find();
    myChan = find_chan(myID);
    current_status = WAITING;
    forks = 0;
    channel_status_t chanStat;
    channel_message_t chanMess;
    while(1){
      if(current_status == WAITING){
        send(REQUEST_FORK, myChan, REQUEST);
        current_status = REQUESTED;
        write( STDOUT_FILENO, "forks requested", 15 );
      }
      else if(current_status == EATING){
        send(RETURN_FORK, myChan, REQUEST);
        forks = 0;
        current_status = WAITING;
        write( STDOUT_FILENO, "forks returned", 14 );
      }
      else if(current_status == REQUESTED){
        chanStat = check_status(myChan);
        if (chanStat == REPLY) {
          chanMess = check_message(myChan);
          if(chanMess == GIVE_FORK){
            forks = 2;
            current_status = EATING;
            write( STDOUT_FILENO, "forks aquired", 13 );
          }
          else if(chanMess == DENY_FORK){
            current_status = WAITING;
            write( STDOUT_FILENO, "forks denied", 12 );
          }
        }
      }
    }
  exit( EXIT_SUCCESS );
}
