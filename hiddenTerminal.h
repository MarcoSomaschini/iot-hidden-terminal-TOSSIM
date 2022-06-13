/**
 *  @author 
 */

#ifndef HIDDENTERM_H
#define HIDDENTERM_H

#define BASE_STATION_ID 1

#define LAMBDA_1 1
#define LAMBDA_2 2
#define LAMBDA_3 3
#define LAMBDA_4 4
#define LAMBDA_5 5

// Generic message
typedef nx_struct my_msg {
	// Sender id
  unit8_t sender_id;
  // Message sequence number
  uint16_t seq_num;
	// Number of retries
  uint8_t n_retries;
} my_msg_t;

// RTS/CTS protocol messages
typedef nx_struct handshake_msg {
  // Message type (RTS, CTS)
  uint8_t type;
  // Sender id
  unit8_t sender_id;
} handshake_msg_t;

enum{
    AM_MY_MSG = 6,
};

#define RTS 0
#define CTS 1

#endif
