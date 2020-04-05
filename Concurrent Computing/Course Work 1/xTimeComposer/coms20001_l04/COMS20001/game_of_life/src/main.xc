// COMS20001 - Cellular Automaton Farm - Initial Code Skeleton
// (using the XMOS i2c accelerometer demo code)
#include <platform.h>
#include <xs1.h>
#include <stdio.h>
#include "pgmIO.h"
#include "i2c.h"
#include <math.h>
#include <print.h>

#define  IMHT 64             //image height
#define  IMWD 64             //image width

typedef unsigned char uchar;      //using uchar as shorthand

on tile[0] : port p_scl = XS1_PORT_1E;          //interface ports to orientation
on tile[0] : port p_sda = XS1_PORT_1F;
on tile[0] : in port buttons = XS1_PORT_4E;     //port to access xCore-200 buttons
on tile[0] : out port leds = XS1_PORT_4F;       //port to access xCore-200 LEDs

//register addresses for orientation
#define FXOS8700EQ_I2C_ADDR 0x1E
#define FXOS8700EQ_XYZ_DATA_CFG_REG 0x0E
#define FXOS8700EQ_CTRL_REG_1 0x2A
#define FXOS8700EQ_DR_STATUS 0x0
#define FXOS8700EQ_OUT_X_MSB 0x1
#define FXOS8700EQ_OUT_X_LSB 0x2
#define FXOS8700EQ_OUT_Y_MSB 0x3
#define FXOS8700EQ_OUT_Y_LSB 0x4
#define FXOS8700EQ_OUT_Z_MSB 0x5
#define FXOS8700EQ_OUT_Z_LSB 0x6

//simple mod function that will also process negative numbers.
int mod(int x, int n){
    return (((x % n) + n) % n);
}

//displays the appropriate LED pattern when it recieves a signal from one of the channels
int showLEDs(out port p, chanend c_dataIn, chanend c_distributor, chanend c_dataOut) {
  int pattern; //1st bit...separate green LED
               //2nd bit...blue LED
               //3rd bit...green LED
               //4th bit...red LED
  while (1) {
      select{
          case c_dataIn :> pattern:         //receive pattern
              p <: pattern;                 //send pattern to LED port
              break;
          case c_distributor :> pattern:    //receive pattern
              p <: pattern;                 //send pattern to LED port
              break;
          case c_dataOut :> pattern:        //recieve pattern
              p <: pattern;                 //send pattern to LED port
              break;
      }
  }
  return 0;
}

//Listens for button input from board
void startButtonListener(in port b, chanend toDataInStream, streaming chanend toDist) {
  int r;
  while (1) {
    b when pinseq(15)  :> r;    // check that no button is pressed
    b when pinsneq(15) :> r;    // check if some buttons are pressed
    if(r==13) toDist <: r;                //if SW2 is pressed, export current image at end of current round
    if(r==14) toDataInStream <: r;        // if SW1 is pressed, start data read in
  }
  return;
}
/////////////////////////////////////////////////////////////////////////////////////////
//
// Read Image from PGM file from path infname[] to channel toDistributor
//
/////////////////////////////////////////////////////////////////////////////////////////
void DataInStream(chanend toDistributor, chanend fromBtn, chanend Leds)
{
  char infname[] = "test64.pgm";     //put your input image path here
  //declaring and initialising functions variables
  int res, buttonPress;
  uchar currentCount = 0;
  uchar valsIn[IMWD], line[ IMWD ];

  printf( "Waiting on SW1 button press...\n");
  //waits for SW1 to be pressed, lights up LED to show reading in image
  fromBtn :> buttonPress;
  Leds <: 4;
  printf( "DataInStream: Start...\n" );
  //Open PGM file
  res = _openinpgm( infname, IMWD, IMHT );
  if( res ) {
     printf( "DataInStream: Error openening %s\n.", infname );
     return;
  }
  //Read data from file a line at a time
  for( int y = 0; y < IMHT; y++ ) {
      _readinline( line, IMWD);
      for( int x = 0; x < IMWD; x++ ) {
          valsIn[x] = line[ x ];
      }
      //packing each row as it is read in
      //convert each row into IMWD/8 uchars
      for (int x = 0; x < IMWD; x++){
          if (valsIn[x] != 0) currentCount = currentCount + (128 / (pow(2, (x%8))));
          if(mod(x+1, 8) == 0){
              //send every packed uchar (previously 8 cells) to the distributor
              toDistributor <: currentCount;
              currentCount = 0;
          }
      }
  }
  //Close PGM image file
  _closeinpgm();
  printf( "DataInStream: Done...\n" );
  //turn off LED
  Leds <: 0;
  return;
}
//checks to see if a bit at a certain position is a 1 or a 0
int bitSet(uchar x, int n)
{
  int i ;
  i = (x & (1 << n));
  if (i == 0){
      return 0;
  }
  else{
      return 1;
  }
}
//finds number of neighbours of middle 6 bits of a uchar
int neighbours(uchar line1, uchar line2, uchar line3, int position)
{
  int noOfNeighbours = 0;
  int i;
  position = 7 - mod(position, 8);
  for (i = -1; i < 2; i++){
      if (bitSet(line1, position + i)) noOfNeighbours +=1;
      if (bitSet(line2, position + i)) noOfNeighbours +=1;
      if (bitSet(line3, position + i)) noOfNeighbours +=1;
  }
  if (bitSet(line2, position)) noOfNeighbours -=1;
  return noOfNeighbours;
}
//finds number of neighbours for leftmost bit of a uchar
int moreNeighboursLeft(uchar line1, uchar line2, uchar line3, uchar left1, uchar left2, uchar left3, int position)
{
  int noOfNeighbours = 0;
  int i;
  position = 7 - mod(position, 8);
  for(i = -1; i < 1; i++){
      if (bitSet(line1, position + i)) noOfNeighbours +=1;
      if (bitSet(line2, position + i)) noOfNeighbours +=1;
      if (bitSet(line3, position + i)) noOfNeighbours +=1;
  }
  if(bitSet(left1, 0)) noOfNeighbours +=1;
  if(bitSet(left2, 0)) noOfNeighbours +=1;
  if(bitSet(left3, 0)) noOfNeighbours +=1;
  if (bitSet(line2, position)) noOfNeighbours -=1;
  return noOfNeighbours;
}
//finds number of neighbouors for righmost bit in uchar
int moreNeighboursRight(uchar line1, uchar line2, uchar line3, uchar right1, uchar right2, uchar right3, int position)
{
  int noOfNeighbours = 0;
  int i;
  position = 7 - mod(position, 8);
  for(i = 1; i > -1; i--){
      if (bitSet(line1, position + i)) noOfNeighbours +=1;
      if (bitSet(line2, position + i)) noOfNeighbours +=1;
      if (bitSet(line3, position + i)) noOfNeighbours +=1;
  }
  if(bitSet(right1, 7)) noOfNeighbours +=1;
  if(bitSet(right2, 7)) noOfNeighbours +=1;
  if(bitSet(right3, 7)) noOfNeighbours +=1;
  if (bitSet(line2, position)) noOfNeighbours -=1;
  return noOfNeighbours;
}
/////////////////////////////////////////////////////////////////////////////////////////
//
// The distributor is the main control hub of the program. It distributed the compressed image
// among the 8 worker threads, it also recieves processed data back from the workers.
// Pausing the program and exporting the current game state is also handled here.
//
/////////////////////////////////////////////////////////////////////////////////////////
void distributor(chanend fromDataPacker, chanend toDataOut, chanend fromAcc, chanend worker[4], streaming chanend asworker[4], chanend Leds, chanend c_timePause, streaming chanend c_export)
{
    //declaring function variables
  int count, LEDCount = 1, roundsPassed = 0, pause, export;
  uchar imageValsInitial[IMWD/8][IMHT];
  for( int y = 0; y < IMHT; y++ ) {                          //go through all lines
      for( int x = 0; x < IMWD/8; x++ ) {                    //go through each pixel per line
          fromDataPacker :> imageValsInitial[x][y];          //recieve the comprssed image one uchar at a time
      }
  }
  printf( "ProcessImage: Start, size = %dx%d\n", IMHT, IMWD );
  printf( "Processing...\n" );
  //starts the timer clock so we can display the current time elapsed when the program is paused
  c_timePause <: 0;
  //continually loops through processing the image until a button press is recognised.
  while(1){
      //updates certain variables for display information, LEDs, distributing arithmetic
      count = 0;
      roundsPassed++;
      Leds <: LEDCount;
      LEDCount = mod(LEDCount + 1, 2);
      //Gives the last row to the first worker, as the game board wraps around
      for(int x = 0; x < IMWD/8; x++){
          worker[0] <: imageValsInitial[x][IMHT-1];
      }
      //distributes the rows among the 8 workers
      for(int y = 0; y < IMHT; y++){
          for(int x = 0; x < IMWD/8; x++){
              if((y/(IMHT/8)) == 0){
                  if(y==0){
                      worker[0] <: imageValsInitial[x][y];
                  }
                  else if(mod((y+1), (IMHT/8)) == 0){
                      worker[0] <: imageValsInitial[x][y];
                      worker[1] <: imageValsInitial[x][y];
                  }
                  else{
                      worker[0] <: imageValsInitial[x][y];
                  }
              }
              else if((y/(IMHT/8)) == 1){
                  if(mod(y, IMHT/8) == 0){
                      worker[0] <: imageValsInitial[x][y];
                      worker[1] <: imageValsInitial[x][y];
                  }
                  else if(mod((y+1), (IMHT/8)) == 0){
                      worker[1] <: imageValsInitial[x][y];
                      worker[2] <: imageValsInitial[x][y];
                  }
                  else{
                      worker[1] <: imageValsInitial[x][y];
                  }
              }
              else if((y/(IMHT/8)) == 2){
                  if(mod(y, IMHT/8) == 0){
                      worker[1] <: imageValsInitial[x][y];
                      worker[2] <: imageValsInitial[x][y];
                  }
                  else if(mod((y+1), (IMHT/8)) == 0){
                      worker[2] <: imageValsInitial[x][y];
                      worker[3] <: imageValsInitial[x][y];
                  }
                  else{
                      worker[2] <: imageValsInitial[x][y];
                  }
              }
              else if((y/(IMHT/8)) == 3){
                  if(mod(y, IMHT/8) == 0){
                      worker[2] <: imageValsInitial[x][y];
                      worker[3] <: imageValsInitial[x][y];
                  }
                  else if(mod((y+1), (IMHT/8)) == 0){
                      worker[3] <: imageValsInitial[x][y];
                      asworker[0] <: imageValsInitial[x][y];
                  }
                  else{
                      worker[3] <: imageValsInitial[x][y];
                  }
              }
              else if((y/(IMHT/8)) == 4){
                  if(mod(y, IMHT/8) == 0){
                      worker[3] <: imageValsInitial[x][y];
                      asworker[0] <: imageValsInitial[x][y];
                  }
                  else if(mod((y+1), (IMHT/8)) == 0){
                      asworker[0] <: imageValsInitial[x][y];
                      asworker[1] <: imageValsInitial[x][y];
                  }
                  else{
                      asworker[0] <: imageValsInitial[x][y];
                  }
              }
              else if((y/(IMHT/8)) == 5){
                  if(mod(y, IMHT/8) == 0){
                      asworker[0] <: imageValsInitial[x][y];
                      asworker[1] <: imageValsInitial[x][y];
                  }
                  else if(mod((y+1), (IMHT/8)) == 0){
                      asworker[1] <: imageValsInitial[x][y];
                      asworker[2] <: imageValsInitial[x][y];
                  }
                  else{
                      asworker[1] <: imageValsInitial[x][y];
                  }
              }
              else if((y/(IMHT/8)) == 6){
                  if(mod(y, IMHT/8) == 0){
                      asworker[1] <: imageValsInitial[x][y];
                      asworker[2] <: imageValsInitial[x][y];
                  }
                  else if(mod((y+1), (IMHT/8)) == 0){
                      asworker[2] <: imageValsInitial[x][y];
                      asworker[3] <: imageValsInitial[x][y];
                  }
                  else{
                      asworker[2] <: imageValsInitial[x][y];
                  }
              }
              else if((y/(IMHT/8)) == 7){
                  if(mod(y, IMHT/8) == 0){
                      asworker[2] <: imageValsInitial[x][y];
                      asworker[3] <: imageValsInitial[x][y];
                  }
                  else{
                      asworker[3] <: imageValsInitial[x][y];
                  }
              }
          }
      }
      //gives the last worker the first row, as the game board wraps around
      for(int x = 0; x < IMWD/8; x++){
          asworker[3] <: imageValsInitial[x][0];
      }

      //recieve data from workers concurrently
      //all declared variables are for keeping track of which row has been sent back, so can re-build the processed
      //image correctly
      int worker1X = 0, worker1Y = 0, worker2X = 0, worker2Y = IMHT/8, worker3X = 0, worker3Y = IMHT/4, worker4X = 0, worker4Y = (3*IMHT/8);
      int worker5X = 0, worker5Y = (IMHT/2), worker6X = 0, worker6Y = (5*IMHT/8), worker7X = 0, worker7Y = (6*IMHT/8), worker8X = 0, worker8Y = (7*IMHT/8);
      int aliveCells = 0, workerCellCount = 0;
      uchar tempValue;
      while (count < IMHT*(IMWD/8)){
          select{
              case worker[0] :> tempValue:
                  imageValsInitial[worker1X][worker1Y] = tempValue;
                  worker1X = mod(worker1X +1, IMWD/8);
                  if (worker1X == 0) worker1Y ++;
                  worker[0] :> workerCellCount;
                  aliveCells +=workerCellCount;
                  count++;
                  break;
              case worker[1] :> tempValue:
                  imageValsInitial[worker2X][worker2Y] = tempValue;
                  worker2X = mod(worker2X +1, IMWD/8);
                  if (worker2X == 0) worker2Y ++;
                  worker[1] :> workerCellCount;
                  aliveCells +=workerCellCount;
                  count++;
                  break;
              case worker[2] :> tempValue:
                  imageValsInitial[worker3X][worker3Y] = tempValue;
                  worker3X = mod(worker3X +1, IMWD/8);
                  if (worker3X == 0) worker3Y ++;
                  worker[2] :> workerCellCount;
                  aliveCells +=workerCellCount;
                  count++;
                  break;
              case worker[3] :> tempValue:
                  imageValsInitial[worker4X][worker4Y] = tempValue;
                  worker4X = mod(worker4X +1, IMWD/8);
                  if (worker4X == 0) worker4Y ++;
                  worker[3] :> workerCellCount;
                  aliveCells +=workerCellCount;
                  count++;
                  break;
              case asworker[0] :> tempValue:
                  imageValsInitial[worker5X][worker5Y] = tempValue;
                  worker5X = mod(worker5X +1, IMWD/8);
                  if (worker5X == 0) worker5Y ++;
                  asworker[0] :> workerCellCount;
                  aliveCells +=workerCellCount;
                  count++;
                  break;
              case asworker[1] :> tempValue:
                  imageValsInitial[worker6X][worker6Y] = tempValue;
                  worker6X = mod(worker6X +1, IMWD/8);
                  if (worker6X == 0) worker6Y ++;
                  asworker[1] :> workerCellCount;
                  aliveCells +=workerCellCount;
                  count++;
                  break;
              case asworker[2] :> tempValue:
                  imageValsInitial[worker7X][worker7Y] = tempValue;
                  worker7X = mod(worker7X +1, IMWD/8);
                  if (worker7X == 0) worker7Y ++;
                  asworker[2] :> workerCellCount;
                  aliveCells +=workerCellCount;
                  count++;
                  break;
              case asworker[3] :> tempValue:
                  imageValsInitial[worker8X][worker8Y] = tempValue;
                  worker8X = mod(worker8X +1, IMWD/8);
                  if (worker8X == 0) worker8Y ++;
                  asworker[3] :> workerCellCount;
                  aliveCells +=workerCellCount;
                  count++;
                  break;
          }
      }
      //Checks to see if the prgram should be paused, or if the user wants to export the current game state
      select{
          case fromAcc :> pause:        //checks if user wants to pause
              c_timePause <: 1;         //pause the timer
              printf("PAUSED\n");
              Leds <: 8 + LEDCount;     //display the Red LED
              float time = 0;
              c_timePause :> time;      //get current elapsed time
              printf("Rounds processed: %d, Number of alive cells for most recent round: %d, Time elapsed: %f seconds \n", roundsPassed, aliveCells, time);
              fromAcc :> pause;         //get signal when want to unpause
              printf("RESUMING\n");
              c_timePause <: 0;         //restart timer
              break;
          case c_export :> export:      //checks if user wants to export current game state
              c_timePause <: 1;         //pause timer
              c_timePause :> export;
              toDataOut <: 1;           //tell data out want to export
              printf("Exporting Data after %d rounds: Start...\n", roundsPassed);
              //export all data in 'packed' form
              for( int q = 0; q < IMHT; q++ ) {                                 //go through all lines
                    for( int r = 0; r < IMWD/8; r++ ) {                         //go through each pixel per line
                        toDataOut <: (uchar)( imageValsInitial[r][q] );         //send processed compressed uchar to data out
                    }
                }
              printf("Exporting Data: Done...\n");
              c_timePause <: 0;         //restart timer
              break;
          default :
              break;
      }
      Leds <: LEDCount;                 //reset LED to what it should show, if the user exported or paused
  }
  return;
}

//worker function that calculates  IMHT/noOfWorkers rows of the image
void worker(chanend c_Dist)
{
    //declare functions variables
    uchar imageValsInitial[IMWD/8][(IMHT/8)+2];
    uchar processedGroup;
    int aliveCells = 0;
    while(1){
        //recieve data from distributor
        for( int y = 0; y < (IMHT/8)+2; y++ ) {   //go through all lines
            for( int x = 0; x < IMWD/8; x++ ) {   //go through each pixel per line
                c_Dist :> imageValsInitial[x][y];
            }
        }
        //functionality for calculating number of neighbours, and applyin the game rules
        int mult8;
        int tempNeighbours = 0;
        for (int j = 1; j< (IMHT/8)+1; j++){
            for (int i = 0; i < IMWD; i++){
                mult8 = i/8; //keeps track of which uchar we are currently looking at, based on position
                if ((mod(i,8) == 0)) processedGroup = imageValsInitial[mult8][mod(j, IMHT)];
                //calculates the number of alive neighbours, calls moreNeighboursLeft or moreNeighboursRight if at boundary of word
                if (mod(i,8) == 0) tempNeighbours = moreNeighboursLeft(imageValsInitial[mult8][mod(j-1, IMHT)], imageValsInitial[mult8][mod(j, IMHT)], imageValsInitial[mult8][mod(j+1, IMHT)],imageValsInitial[mod(mult8-1, IMWD / 8)][mod(j-1, IMHT)], imageValsInitial[mod(mult8-1, IMWD / 8)][mod(j, IMHT)], imageValsInitial[mod(mult8-1, IMWD / 8)][mod(j+1, IMHT)], i);
                else if (mod(i+1, 8) == 0) tempNeighbours = moreNeighboursRight(imageValsInitial[mult8][mod(j-1, IMHT)], imageValsInitial[mult8][mod(j, IMHT)], imageValsInitial[mult8][mod(j+1, IMHT)],imageValsInitial[mod(mult8+1, IMWD / 8)][mod(j-1, IMHT)], imageValsInitial[mod(mult8+1, IMWD / 8)][mod(j, IMHT)], imageValsInitial[mod(mult8+1, IMWD / 8)][mod(j+1, IMHT)], i);
                else tempNeighbours = neighbours(imageValsInitial[mult8][mod(j-1, IMHT)], imageValsInitial[mult8][mod(j, IMHT)], imageValsInitial[mult8][mod(j+1, IMHT)], i);

                //Rules for if the cell is dead
                if(bitSet(imageValsInitial[mult8][j], 7-mod(i,8)) == 0){ //check if the cell is dead
                    if(tempNeighbours == 3) processedGroup = processedGroup + pow(2,7-mod(i,8));
                }
                //rules for if cell is alive
                else if(bitSet(imageValsInitial[mult8][j],7-mod(i,8) ) == 1){ //check if the cell is alive
                    aliveCells++;
                    if(tempNeighbours < 2) processedGroup = processedGroup - pow(2,7-mod(i,8));
                    else if(tempNeighbours > 3) processedGroup = processedGroup - pow(2,7-mod(i,8));
                    else processedGroup = processedGroup;
                }
                //send the number of alive cells, and the processed uchars as soon as they're computed to distributor
                if ((mod(i+1,8)==0)){
                    c_Dist <: processedGroup;
                    c_Dist <: aliveCells;
                    aliveCells = 0;
                }
            }
        }
    }
    return;
}

//identical as other worker, but channel used is asynchronous
void asWorker(streaming chanend c_Dist)
{
    uchar imageValsInitial[IMWD/8][(IMHT/8)+2];
    uchar processedGroup;
    int aliveCells = 0;
    while(1){
        for( int y = 0; y < (IMHT/8)+2; y++ ) {   //go through all lines
            for( int x = 0; x < IMWD/8; x++ ) {   //go through each pixel per line
                c_Dist :> imageValsInitial[x][y];
            }
        }
        int mult8;
        int tempNeighbours = 0;
        for (int j = 1; j< (IMHT/8)+1; j++){
            for (int i = 0; i < IMWD; i++){
                mult8 = i/8; //keeps track of which uchar we are currently looking at, based on position
                if ((mod(i,8) == 0)) processedGroup = imageValsInitial[mult8][mod(j, IMHT)];
                //calculates the number of alive neighbours, calls moreNeighboursLeft or moreNeighboursRight if at boundary of word
                if (mod(i,8) == 0) tempNeighbours = moreNeighboursLeft(imageValsInitial[mult8][mod(j-1, IMHT)], imageValsInitial[mult8][mod(j, IMHT)], imageValsInitial[mult8][mod(j+1, IMHT)],imageValsInitial[mod(mult8-1, IMWD / 8)][mod(j-1, IMHT)], imageValsInitial[mod(mult8-1, IMWD / 8)][mod(j, IMHT)], imageValsInitial[mod(mult8-1, IMWD / 8)][mod(j+1, IMHT)], i);
                else if (mod(i+1, 8) == 0) tempNeighbours = moreNeighboursRight(imageValsInitial[mult8][mod(j-1, IMHT)], imageValsInitial[mult8][mod(j, IMHT)], imageValsInitial[mult8][mod(j+1, IMHT)],imageValsInitial[mod(mult8+1, IMWD / 8)][mod(j-1, IMHT)], imageValsInitial[mod(mult8+1, IMWD / 8)][mod(j, IMHT)], imageValsInitial[mod(mult8+1, IMWD / 8)][mod(j+1, IMHT)], i);
                else tempNeighbours = neighbours(imageValsInitial[mult8][mod(j-1, IMHT)], imageValsInitial[mult8][mod(j, IMHT)], imageValsInitial[mult8][mod(j+1, IMHT)], i);

                //Rules for if the cell is dead
                if(bitSet(imageValsInitial[mult8][j], 7-mod(i,8)) == 0){ //check if the cell is dead
                    if(tempNeighbours == 3) processedGroup = processedGroup + pow(2,7-mod(i,8));
                }
                //rules for if cell is alive
                else if(bitSet(imageValsInitial[mult8][j],7-mod(i,8) ) == 1){ //check if the cell is alive
                    aliveCells++;
                    if(tempNeighbours < 2) processedGroup = processedGroup - pow(2,7-mod(i,8));
                    else if(tempNeighbours > 3) processedGroup = processedGroup - pow(2,7-mod(i,8));
                    else processedGroup = processedGroup;
                }
                //send the number of alive cells, and the processed uchars as soon as they're computed
                if ((mod(i+1,8)==0)){
                    c_Dist <: processedGroup;
                    c_Dist <: aliveCells;
                    aliveCells = 0;
                }
            }
        }
    }
    return;
}

//function to time how long prosessing takes
void mytimer(chanend c_timePause)
{
    int pause;
    timer t;
    unsigned int time;
    const unsigned int period = 100000; //time period of one 1/1000 second
    float timercount = 0; //number of seconds
    c_timePause :> pause;
    t :> time;
    while (1) {
        select {
            //keep track of time elapsed since processing started
            case t when timerafter (time) :> void:
                timercount +=1;
                time += period;
                break;
            case c_timePause :> pause:              //pause functionality to pause the computation of time elapsed so
                c_timePause <: timercount/1000;     //that accurate compute times are displayed and calculated
                c_timePause :> pause;
                t :> time;
                break;
        }
    }
    return;
}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Write pixel stream from channel c_in to PGM image file
//
/////////////////////////////////////////////////////////////////////////////////////////
void DataOutStream(chanend c_in, chanend Leds)
{
  char outfname[] = "testout.pgm"; //put your output image path here
  int res, export;
  uchar dataOut[IMWD/8];
  uchar line[ IMWD ];
  //listens always for export signal from distributor
  while(1){
      select{
          case c_in :> export:
              res = _openoutpgm( outfname, IMWD, IMHT );        //Open PGM file
                      if( res ) {
                        printf( "DataOutStream: Error opening %s\n.", outfname );
                        return;
                      }
                      //Compile each line of the image and write the image line-by-line
                      for( int y = 0; y < IMHT; y++ ) {
                        for( int x = 0; x < IMWD/8; x++ ) {
                            c_in :> dataOut[ x ];
                            if(y==0) Leds <: 2;
                        }
                        //unpack the data into 8 cell values to be written to the file
                        //this is done one line at a time
                        int j;
                        for(int x = 0; x < IMWD; x++){
                            j = x/8;
                            line[ x ] = bitSet(dataOut[j], 7 - mod(x,8)) * 255;
                        }
                        _writeoutline( line, IMWD );
                      }
                      //Close the PGM image
                      _closeoutpgm();
                      //turn off blue LED
                      Leds <: 0;
                      break;
      }
  }
  return;
}
/////////////////////////////////////////////////////////////////////////////////////////
//
// Initialise and  read orientation, send first tilt event to channel
//
/////////////////////////////////////////////////////////////////////////////////////////

void orientation( client interface i2c_master_if i2c, chanend toDist)
{
  i2c_regop_res_t result;
  char status_data = 0;
  int tilted = 0;
  // Configure FXOS8700EQ
  result = i2c.write_reg(FXOS8700EQ_I2C_ADDR, FXOS8700EQ_XYZ_DATA_CFG_REG, 0x01);
  if (result != I2C_REGOP_SUCCESS) {
    printf("I2C write reg failed\n");
  }
  // Enable FXOS8700EQ
  result = i2c.write_reg(FXOS8700EQ_I2C_ADDR, FXOS8700EQ_CTRL_REG_1, 0x01);
  if (result != I2C_REGOP_SUCCESS) {
    printf("I2C write reg failed\n");
  }
  //Probe the orientation x-axis forever
  while (1) {
    //check until new orientation data is available
    do {
      status_data = i2c.read_reg(FXOS8700EQ_I2C_ADDR, FXOS8700EQ_DR_STATUS, result);
    } while (!status_data & 0x08);
    //get new x-axis tilt value
    int x = read_acceleration(i2c, FXOS8700EQ_OUT_X_MSB);
    //send signal to distributor after first tilt
    if (!tilted) {
      if (x>30 || x<-30) {
        tilted = 1 - tilted;
        toDist <: 1;
      }
    }
    //if board had been tilted, but now flat again, need to tell distributor so can unpause system
    if (tilted) {
        if (x<30 && x>-30) {
            tilted = 1 - tilted;
            toDist <:0;
        }
    }
  }
  return;
}
/////////////////////////////////////////////////////////////////////////////////////////
//
// Orchestrate concurrent system and start up all threads
//
/////////////////////////////////////////////////////////////////////////////////////////
int main(void)
{
  i2c_master_if i2c[1];               //interface to orientation
  chan c_inIO, c_outIO, c_control, c_buttons, c_dataOutLEDS, c_distributorLEDS, c_dataInLEDS, c_timePause;    //extend your channel definitions here
  streaming chan c_buttonExport;
  chan c_work[4];               //workers that use synchronous communication
  streaming chan c_asWork[4];   //workers that use asynchronous comminication
  par {
      on tile[0] : startButtonListener(buttons, c_buttons, c_buttonExport);             //button listener thread, listens for any button threads
      on tile[0] : i2c_master(i2c, 1, p_scl, p_sda, 10);                                //server thread providing orientation data
      on tile[0] : showLEDs(leds, c_dataInLEDS, c_distributorLEDS, c_dataOutLEDS);      //function to light up relevant LEDs when it recieves signals to do so
      on tile[0] : DataInStream(c_inIO, c_buttons, c_dataInLEDS);                       //thread to read in a PGM image
      on tile[1] : DataOutStream(c_outIO, c_dataOutLEDS);                               //thread to write out a PGM image
      on tile[1] : orientation(i2c[0],c_control);                                       //client thread reading orientation data
      on tile[1] : mytimer(c_timePause);                                                //timer thread for keeping current time elapsed

      //distributor thread, sends data to worker threads on respective channels, requires 8 channels, 1 for each worker
      on tile[1] : distributor(c_inIO, c_outIO, c_control, c_work, c_asWork, c_distributorLEDS, c_timePause, c_buttonExport);//thread to coordinate work on image

      //all 8 worker threads in two replicated par statements
      par (int i=0; i<4; i++) {
          on tile[0]: worker(c_work[i]);
      }
      par (int i=0; i<4; i++) {
          on tile[1]: asWorker(c_asWork[i]);
      }
  }
  return 0;
}
