/* Copyright (C) 2017 Daniel Page <csdsp@bristol.ac.uk>
 *
 * Use of this source code is restricted per the CC BY-NC-ND license, a copy of
 * which can be found via http://creativecommons.org (and should be included as
 * LICENSE.txt within the associated archive or repository).
 */

#include "hilevel.h"

pcb_t pcb[ 32 ]; pcb_t* current = NULL;
channel_t channels[32];
extern uint32_t tos_ALL;
extern uint32_t tos_svc;
extern void main_console();

int mod(int x, int y){
  return x-(x/y)*y;
}

void dispatch( ctx_t* ctx, pcb_t* prev, pcb_t* next ) {
  char prev_pid = '?', next_pid = '?';
  int previous = 0, nextP = 0;

  if( NULL != prev ) {
    memcpy( &prev->ctx, ctx, sizeof( ctx_t ) ); // preserve execution context of P_{prev}
    prev_pid = '0' + prev->pid;
    previous = 0 + prev->pid;
  }
  if( NULL != next ) {
    memcpy( ctx, &next->ctx, sizeof( ctx_t ) ); // restore  execution context of P_{next}
    next_pid = '0' + next->pid;
    nextP = 0 + next->pid;
  }

    PL011_putc( UART0, '[',      true );
    if (previous < 10) PL011_putc( UART0, prev_pid, true );
    else {
      PL011_putc( UART0, '0' + (previous/10),      true );
      PL011_putc( UART0, '0' + (mod(previous, 10)),      true );
    }
    PL011_putc( UART0, '-',      true );
    PL011_putc( UART0, '>',      true );
    if (nextP < 10) PL011_putc( UART0, (char) next_pid, 2 );
    else{
      PL011_putc( UART0, '0' + (nextP/10),      true );
      PL011_putc( UART0, '0' + (mod(nextP, 10)),      true );
    }
    PL011_putc( UART0, ']',      true );

    current = next;                             // update   executing index   to P_{next}

  return;
}

void prioritySchedule( ctx_t* ctx) {
  int currentProg;
  int next = 0;
  //increases age of all programs not being executed
  for (int i = 0; i < 32; i++) {
    if(pcb[i].pid == current->pid) currentProg = i;
    else if (pcb[i].status != STATUS_TERMINATED || pcb[i].status != STATUS_WAITING) {
      pcb[i].age = pcb[i].age + 1;
    }
  }
  //finds next program to be executed
  for (int i = 1; i < 32; i++) {
    if (pcb[i].status != STATUS_TERMINATED) {
      if ((pcb[i].priority + pcb[i].age) > (pcb[next].priority + pcb[next].age)) next = i;
      else if ((pcb[i].priority + pcb[i].age) == (pcb[next].priority + pcb[next].age)){
        if(pcb[i].priority > pcb[next].priority) next = i;
      }
    }
  }
  //context switches
  if (next == currentProg);
  else {
    pcb[next].age = 0;
    dispatch(ctx, &pcb[currentProg], &pcb[next]);
    pcb[currentProg].status = STATUS_READY;
    pcb[next].status = STATUS_EXECUTING;
  }
  return;
}

void init_channels(){
  for (int i = 0; i < 32; i++) {
    memset( &channels[ i ], 0, sizeof(channel_t) );
    channels[i].status = TERMINATED;
  }
}

void hilevel_handler_rst( ctx_t* ctx  ) {
  /* Configure the mechanism for interrupt handling by
   *
   * - configuring timer st. it raises a (periodic) interrupt for each
   *   timer tick,
   * - configuring GIC st. the selected interrupts are forwarded to the
   *   processor via the IRQ interrupt signal, then
   * - enabling IRQ interrupts.
   */

  PL011_putc( UART0, 'R',      true );

  init_channels();
  memset( &pcb[ 0 ], 0, sizeof(pcb_t) );
  pcb[ 0 ].pid      = 1;
  pcb[ 0 ].status   = STATUS_CREATED;
  pcb[ 0 ].ctx.cpsr = 0x50;
  pcb[ 0 ].ctx.pc   = ( uint32_t )( &main_console );
  pcb[ 0 ].tos      = (( uint32_t )(&tos_ALL)) - 0x00001000;
  pcb[ 0 ].ctx.sp   = ( uint32_t ) pcb[0].tos;
  pcb[ 0 ].priority = 6;
  pcb[ 0 ].age      = 0;

  //initialise rest of pcb
  for (int i = 1; i < 32; i++) {
    memset( &pcb[ i ], 0, sizeof(pcb_t) );
    pcb[i].status = STATUS_TERMINATED;
  }

  TIMER0->Timer1Load  = 0x00100000; // select period = 2^20 ticks ~= 1 sec
  TIMER0->Timer1Ctrl  = 0x00000002; // select 32-bit   timer
  TIMER0->Timer1Ctrl |= 0x00000040; // select periodic timer
  TIMER0->Timer1Ctrl |= 0x00000020; // enable          timer interrupt
  TIMER0->Timer1Ctrl |= 0x00000080; // enable          timer

  UART0->IMSC       |= 0x00000010; // enable UART    (Rx) interrupt
  UART0->CR          = 0x00000301; // enable UART (Tx+Rx)

  GICC0->PMR          = 0x000000F0; // unmask all            interrupts
  GICD0->ISENABLER1  |= 0x00000010; // enable timer          interrupt
  GICC0->CTLR         = 0x00000001; // enable GIC interface
  GICD0->CTLR         = 0x00000001; // enable GIC distributor


  dispatch( ctx, NULL, &pcb[ 0 ] );
  int_enable_irq();
  return;
}

void hilevel_handler_irq(ctx_t* ctx) {
  // Step 2: read  the interrupt identifier so we know the source.

  uint32_t id = GICC0->IAR;

  // Step 4: handle the interrupt, then clear (or reset) the source.

  if( id == GIC_SOURCE_TIMER0 ) {
    PL011_putc( UART0, 'T', true );
    prioritySchedule(ctx);
    TIMER0->Timer1IntClr = 0x01;
  }

  // Step 5: write the interrupt identifier to signal we're done.

  GICC0->EOIR = id;

  return;
}

void hilevel_handler_svc( ctx_t* ctx, uint32_t id ) {
  /* Based on the identifier (i.e., the immediate operand) extracted from the
   * svc instruction,
   *
   * - read  the arguments from preserved usr mode registers,
   * - perform whatever is appropriate for this system call, then
   * - write any return value back to preserved usr mode registers.
   */

  switch( id ) {
    case 0x00 : { // 0x00 => yield()
      prioritySchedule( ctx );

      break;
    }

    case 0x01 : { // 0x01 => write( fd, x, n )  user_prog_count = 1;
      int   fd = ( int   )( ctx->gpr[ 0 ] );
      char*  x = ( char* )( ctx->gpr[ 1 ] );
      int    n = ( int   )( ctx->gpr[ 2 ] );

      for( int i = 0; i < n; i++ ) {
        PL011_putc( UART0, *x++, true );
      }

      ctx->gpr[ 0 ] = n;

      break;
    }

    case 0x02 : {// 0x02 => read(fd,x,n );
      break;
    }

    case 0x03 : {// 0x03 => fork();
      for (int i = 0; i < 32; i++) {
        if(pcb[i].status == STATUS_TERMINATED){       //find availible pcb slot
          memcpy(&pcb[i], current, sizeof(pcb_t));
          memcpy(&pcb[i].ctx, ctx, sizeof(ctx_t));     //copy parent into child
          pcb[i].pid = i + 1;             // give child new id
          pcb[i].tos = ((uint32_t) &tos_ALL) - (pcb[i].pid * 0x00001000);
          pcb[i].ctx.sp = pcb[i].tos - (current->tos - ctx->sp);  //sets the stack pointer offset and tos offset to be the same
          memcpy((void*)(pcb[i].tos - 0x00001000), (void*)(current->tos - 0x00001000), 0x00001000);   //copy parent stack
          pcb[i].status = STATUS_CREATED;
          pcb[i].priority = 5;
          pcb[i].age = 0;
          ctx->gpr[0] = (uint32_t) pcb[i].pid;        //parent returns new child's id
          pcb[i].ctx.gpr[0] = (uint32_t) 0;           //child returns 0
          break;
        }
      }
      break;
    }

    case 0x04 : {// 0x04 => exit(x);
      current->status = STATUS_TERMINATED;
      dispatch(ctx, current, &pcb[0]);
      break;
    }

    case 0x05 : {// 0x05 => exec(x);
      ctx->pc = (uint32_t) ctx->gpr[0];
      ctx->sp = current->tos;
      break;
    }

    case 0x07 : {// 0x07 => nice(pid, x);
      pcb[ctx->gpr[0] - 1].priority = ctx->gpr[1];
      break;
    }

    case 0x08 : {// 0x08 => status(pid, x);
      pcb[ctx->gpr[0] - 1].status = ctx->gpr[1];
      break;
    }

    case 0x09 : {// 0x09 => create(int source, int destination);
      for (int i = 0; i < 32; i++) {
        if(channels[i].status == TERMINATED){
          channels[i].id = i+1;
          channels[i].status = EMPTY;
          channels[i].source = ctx->gpr[0];
          channels[i].destination = ctx->gpr[1];
          channels[i].message = NO_MESSAGE;
          ctx->gpr[0] = channels[i].id;
        }
      }
      break;
    }

    case 0x0A : {// 0x0A => send(int m, int x, int q);
      channels[ctx->gpr[1]-1].message = ctx->gpr[0];
      channels[ctx->gpr[1]-1].status = ctx->gpr[2];
      break;
    }

    case 0x0B : {// 0x0B => check_status(int x);
      int x = ctx->gpr[0] - 1;
      ctx->gpr[0] = channels[x].status;
      break;
    }

    case 0x0C : {// 0x0C => find();
      ctx->gpr[0] = current->pid;
      break;
    }

    case 0x0D : {// 0x0D => check_message(int x);
      int x = ctx->gpr[0] - 1;
      ctx->gpr[0] = channels[x].message;
      break;
    }

    case 0x0E : {// 0x0E => find_chan(int id);
      int x = ctx->gpr[0];
      for (int i = 0; i < 32; i++) {
        if(channels[i].destination == x){
          ctx->gpr[0] = i+1;
        }
        break;
      }
      break;
    }

    default   : { // 0x?? => unknown/unsupported
      break;
    }
  }

  return;
}





/*
have a channel struct
each philosopher has a channel to waiter (channel has pcb index of each end of channel)
when philosopher has processor time, it either sends a request for some forks, returns forks, continues relating
when waiter is on processor time, it checks all channels and processes the requests


CREATE channel
SEND TO channel
CHECK channel

waiter needs all channels
philosopher needs to find its channel



*/
