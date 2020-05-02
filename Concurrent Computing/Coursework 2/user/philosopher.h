/* Copyright (C) 2017 Daniel Page <csdsp@bristol.ac.uk>
 *
 * Use of this source code is restricted per the CC BY-NC-ND license, a copy of
 * which can be found via http://creativecommons.org (and should be included as
 * LICENSE.txt within the associated archive or repository).
 */

#ifndef __philosopher_H
#define __philosopher_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include "libc.h"

typedef enum {
  REQUESTED,
  EATING,
  WAITING
}my_status_t;

typedef enum {
  REQUEST,
  REPLY,
  EMPTY,
  TERMINATED
} channel_status_t;

typedef enum {
  REQUEST_FORK,
  RETURN_FORK,
  GIVE_FORK,
  DENY_FORK,
  NO_MESSAGE
} channel_message_t;

#endif
