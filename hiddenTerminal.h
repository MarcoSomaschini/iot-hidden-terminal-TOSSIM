/**
 *  @author Marco Somaschini 10561636
 */

#ifndef HIDDENTERM_H
#define HIDDENTERM_H

#define BASE_STATION_ID 1

// SENDER MOTES Poisson lambdas
#define LAMBDA_2 5
#define LAMBDA_3 10
#define LAMBDA_4 5
#define LAMBDA_5 10
#define LAMBDA_6 5

// EVEN MOTES CSMA parameters
#define MAXBE 7
#define BACKOFFPERIOD 10

// Time interval before the base station stops accepting transmissions
#define STOP_INT 300

// Generic message
typedef nx_struct my_msg {
  // Sender id
  nx_uint8_t sender_id;
  // Message sequence number
  nx_uint16_t seq_num;
  // Number of retries
  nx_uint8_t n_retries;
} my_msg_t;

enum{
    AM_MY_MSG = 6,
};

#endif
