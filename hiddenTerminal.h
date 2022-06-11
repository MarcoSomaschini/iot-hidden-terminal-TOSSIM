/**
 *  @author 
 */

#ifndef HIDDENTERM_H
#define HIDDENTERM_H

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
