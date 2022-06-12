/**
 *  Source file for implementation of module sendAckC in which
 *  the node 1 send a request to node 2 until it receives a response.
 *  The reply message contains a reading from the Fake Sensor.
 *
 *  @author 
 */

#include "hiddenTerminal.h"

#include "Timer.h"

#include <math.h>

module hiddenTerminalC {

  uses {
  /****** INTERFACES *****/
	interface Boot; 
	
    //interfaces for communication
    interface Receive;
    interface AMSend;
    interface SplitControl;
    interface Packet;

	//interface for timer
    interface Timer<TMilli> as MilliTimer;

    //other interfaces, if needed
    interface Random;

  }

} implementation {

  // Lambda associated with the sender motes
  uint32_t lambda[] = {0, LAMBDA_1, LAMBDA_2, LAMBDA_3, LAMBDA_4, LAMBDA_5};
  // Packet Error Rate of each sender mote
  float per[N_MOTES];
  
  message_t packet;

  uint32_t getInterArrivalTimePoisson(uint32_t l);


  //***************** Boot interface ********************//
  event void Boot.booted() {
    dbg("Boot","Mote booted. ID is %d\n", TOS_NODE_ID);

    // From here we just switch on the radio
    call SplitControl.start();
  }

  //***************** SplitControl interface ********************//
  event void SplitControl.startDone(error_t err) {
    uint32_t dt;
  
    if (err != SUCCESS) {
		dbg("Radio","SplitControl %d failed to start, retrying...\n", TOS_NODE_ID);

		call SplitControl.start();
		return;
    }
    
    if (TOS_NODE_ID == 1) {
      // This node is elected as BASE STATION
    }
    else {
      // The other nodes are SENDER MOTES

      // Generate first inter-arrival time according to mote's lambda
      dt = getInterArrivalTimePoisson(lambda[TOS_NODE_ID - 1]);
      dbg("Radio","Timer on mote #%d will trigger in %d\n", TOS_NODE_ID, dt);

	  // Set first Timer to start routine
      call MilliTimer.startOneShot(dt);
    }
  }
  
  event void SplitControl.stopDone(error_t err){
    /* Fill it ... */
  }

  //***************** MilliTimer interface ********************//
  event void MilliTimer.fired() {
    uint32_t dt;   
  
	// Generate and send packet
    dbg("Timer","Timer on mote #%d fired!\n", TOS_NODE_ID);

    // TODO Only here for testing
    dt = getInterArrivalTimePoisson(lambda[TOS_NODE_ID - 1]);
    dbg("Timer","Timer on mote #%d will trigger in %d\n", TOS_NODE_ID, dt);
    
    call MilliTimer.startOneShot(dt);
  }
  

  //********************* AMSend interface ****************//
  event void AMSend.sendDone(message_t* buf,error_t err) {
	/* This event is triggered when a message is sent 
	 *
	 * STEPS:
	 * 1. Check if the packet is sent
	 * 2. Check if the ACK is received (read the docs)
	 * 2a. If yes, stop the timer according to your id. The program is done
	 * 2b. Otherwise, send again the request
	 * X. Use debug statements showing what's happening (i.e. message fields)
	 */
	// MOTES ONLY
	 
	// Wait for ACK, resend if not acked

	// Simulate new inter-arrival time
	// Set new Timer
  }
  

  //***************************** Receive interface *****************//
  event message_t* Receive.receive(message_t* buf,void* payload, uint8_t len) {
	/* This event is triggered when a message is received 
	 *
	 * STEPS:
	 * 1. Read the content of the message
	 * 2. Check if the type is request (REQ)
	 * 3. If a request is received, send the response
	 * X. Use debug statements showing what's happening (i.e. message fields)
	 */
	// STATION ONLY
	
	// Inspect message and update mote's PER	
  }


  uint32_t getInterArrivalTimePoisson(uint32_t l) {
    float p_unif;
    float int_arr_time;
    float milliLambda = (float) l;
    
    milliLambda = milliLambda / 1000;
    
    p_unif = call Random.rand16();
    p_unif = p_unif / UINT16_MAX;
    
    int_arr_time = -logf(1 - p_unif) / milliLambda;
	
    return (uint32_t) int_arr_time;
  }

}

