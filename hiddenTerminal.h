/**
 *  @author 
 */

#ifndef HIDDENTERM_H
#define HIDDENTERM_H

#define BASE_STATION_ID 1

#define LAMBDA_1 20
#define LAMBDA_2 10
#define LAMBDA_3 10
#define LAMBDA_4 5
#define LAMBDA_5 10

#define MAXBE 7
#define BACKOFFPERIOD 10

#define LOG_INTERVAL 10

// Generic message
typedef nx_struct my_msg {
  // Sender id
  nx_uint8_t sender_id;
  // Message sequence number
  nx_uint16_t seq_num;
  // Number of retries
  nx_uint8_t n_retries;
} my_msg_t;

// RTS/CTS protocol messages
typedef nx_struct handshake_msg {
  // Message type (RTS, CTS)
  nx_uint8_t type;
  // Sender id
  nx_uint8_t sender_id;
} handshake_msg_t;

enum{
    AM_MY_MSG = 6,
};

#define RTS 0
#define CTS 1

#endif
