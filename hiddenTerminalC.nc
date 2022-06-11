/**
 *  Source file for implementation of module sendAckC in which
 *  the node 1 send a request to node 2 until it receives a response.
 *  The reply message contains a reading from the Fake Sensor.
 *
 *  @author 
 */

#include "hiddenTerminal.h"
#include "Timer.h"

module hiddenTerminalC {

  uses {
  /****** INTERFACES *****/
	interface Boot; 
	
    //interfaces for communication
	//interface for timer
    //other interfaces, if needed
	
	//interface used to perform sensor reading (to get the value from a sensor)
	interface Read<uint16_t>;
  }

} implementation {

  // Lambda associated with the sender motes
  uint8_t lambda[];
  // Packet Error Rate of each sender mote
  uint8_t per[];
  
  message_t packet;


  //***************** Boot interface ********************//
  event void Boot.booted() {
    dbg("boot","Application booted. ID is %d\n", TOS_NODE_ID);

    // From here we just switch on the radio
    call SplitControl.start();
  }

  //***************** SplitControl interface ********************//
  event void SplitControl.startDone(error_t err) {
    if (err != SUCCESS) {
		dbg("startDone","Mote %d failed to start, retrying...\n", TOS_NODE_ID);

		return call SplitControl.start();
    }
    
    if (TOS_NODE_ID == 1) {
    	// This node is elected as BASE STATION
    }
    else {
    	// The other nodes are SENDER MOTES
    	
    	// Generate first inter-arrival time according to mote's lambda
		// Set first Timer to start routine		
    }
  }
  
  event void SplitControl.stopDone(error_t err){
    /* Fill it ... */
  }

  //***************** MilliTimer interface ********************//
  event void MilliTimer.fired() {
	// Generate and send packet
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
  
  
}

