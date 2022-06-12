/**
 *  @author 
 */

#ifndef HIDDENTERM_H
#define HIDDENTERM_H

#define N_MOTES 5

#define LAMBDA_1 1
#define LAMBDA_2 2
#define LAMBDA_3 3
#define LAMBDA_4 4
#define LAMBDA_5 5

//payload of the msg
typedef nx_struct my_msg {
	//message type (CONTENT, RTS, CTS)
	//sender id
	//num of retries (only CONTENT msgs)
	//payload (rng) (only CONTENT msgs)
} my_msg_t;

#define REQ 1
#define RESP 2 

#endif
