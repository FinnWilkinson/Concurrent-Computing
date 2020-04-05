/*
 * test.xc
 *
 *  Created on: 14 Nov 2018
 *      Author: Tom
 */

#include <platform.h>
#include <xs1.h>
#include <stdio.h>
#include <math.h>
#include <print.h>

typedef unsigned char uchar;

//simple mod function
int mod(int x, int n){
    return (((x % n) + n) % n);
}
//checks to see if a bit at a certain position is set or not
int bitSet(uchar x, int n){
    int i ;
    i = (x & (1 << n));
    if (i == 0){
        return 0;
    }
    else{
        return 1;
    }
}
//really fucking clever imo
int neighbours(uchar line1, uchar line2, uchar line3, int position){
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
//a fuck off big version of the previous function
int moreNeighboursLeft(uchar line1, uchar line2, uchar line3, uchar left1, uchar left2, uchar left3, int position){
    int noOfNeighbours = 0;
    int i;
    position = 7 - mod(position, 8);
    for(i = 0; i < 2; i++){
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

int moreNeighboursRight(uchar line1, uchar line2, uchar line3, uchar right1, uchar right2, uchar right3, int position){
    int noOfNeighbours = 0;
    int i;
    position = 7 - mod(position, 8);
    for(i = -1; i < 1; i++){
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
int testing1(void){
    int imagewidth;
        int imgh;
        int mult8;
        int wordwidth;

        //small array decleration
        uchar words[2][3];
        words[0][0] = 8;
        words[1][0] = 0;
        words[0][1] = 4;
        words[1][1] = 0;
        words[0][2] = 28;
        words[1][2] = 0;

        imagewidth = 8;
        imgh = 3;
        wordwidth = imagewidth/8;
        //need to add variable for keeping words width

        for (int j = 0; j< imgh; j++){
            for (int i = 0; i < imagewidth; i++){
                mult8 = i/8;
                   if (mod(i,8) == 0){
                       printf("%d ", moreNeighboursLeft(words[mult8][mod(j-1, imgh)], words[mult8][mod(j, imgh)], words[mult8][mod(j+1, imgh)],words[mod(mult8-1, wordwidth)][mod(j-1, imgh)], words[mod(mult8-1, wordwidth)][mod(j, imgh)], words[mod(mult8-1, wordwidth)][mod(j+1, imgh)], i));
                   }
                   else if (mod(i+1, 8) == 0){
                       printf("%d ", moreNeighboursRight(words[mult8][mod(j-1, imgh)], words[mult8][mod(j, imgh)], words[mult8][mod(j+1, imgh)],words[mod(mult8+1, wordwidth)][mod(j-1, imgh)], words[mod(mult8+1, wordwidth)][mod(j, imgh)], words[mod(mult8+1, wordwidth)][mod(j+1, imgh)], i));
                       printf("| ");
                   }
                   else{
                       printf("%d ", neighbours(words[mult8][mod(j-1, imgh)], words[mult8][mod(j, imgh)], words[mult8][mod(j+1, imgh)], i));
                   }
               }
            printf("\n");
        }
        return 0;
}

int main(void){
    //testing1();


    printf("%d", bitSet(28, 3));




    return 0;
}
