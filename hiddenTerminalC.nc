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
    interface PacketAcknowledgements;

  }

} implementation {

  // Lambda associated with the motes
  uint8_t lambda[] = {0, LAMBDA_1, LAMBDA_2, LAMBDA_3, LAMBDA_4, LAMBDA_5};

  // Packet Error Rate of each mote
  float per[] = {0.0, 0.0, 0.0, 0.0, 0.0, 0.0};
  
  message_t packet;
  // Current sequence number per mote
  uint16_t seq[] = {1, 1, 1, 1, 1, 1};
  // Current number of retries per mote
  uint16_t retries[] = {0, 0, 0, 0, 0, 0};

  // Possion simulation function
  uint32_t millisToNextPoisson(uint8_t l);
  // Procedure to generate and send a packet
  void sendNextPacket();


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
      dbg("Radio","Mote #%d: SplitControl failed to start, retrying...\n", TOS_NODE_ID);

		  call SplitControl.start();
		  return;
    }
    
    if (TOS_NODE_ID == BASE_STATION_ID) {
      // This node is elected as BASE STATION
    }
    else {
      // The other nodes are SENDER MOTES

      // Generate first inter-arrival time according to mote's lambda
      dt = millisToNextPoisson(lambda[TOS_NODE_ID - 1]);
      dbg("Timer","Mote #%d: Timer will trigger in %d [ms]\n", TOS_NODE_ID, dt);

      // Set first Timer to start routine
      call MilliTimer.startOneShot(dt);
    }
  }

  
  event void SplitControl.stopDone(error_t err){
    /* Fill it ... */
  }


  //***************** MilliTimer interface ********************//
  event void MilliTimer.fired() {
    dbg("Timer","Mote #%d: Timer fired!\n", TOS_NODE_ID);

	  // Generate and send packet
    sendNextPacket();
  }
  

  //********************* AMSend interface ****************//
  event void AMSend.sendDone(message_t* buf,error_t err) {
    // MOTES ONLY (as long as no RTS/CTS is used)
    uint32_t dt;

    // Wait for ACK, resend if not acked
    if (call PacketAcknowledgements.wasAcked(buf) == TRUE) {
      dbg("Radio", "Mote #%d: ACK for Packet n°%d received!\n", TOS_NODE_ID, seq[TOS_NODE_ID - 1]);

      seq[TOS_NODE_ID - 1] += 1;
      retries[TOS_NODE_ID - 1] = 0;

      // Simulate new inter-arrival time
      dt = millisToNextPoisson(lambda[TOS_NODE_ID - 1]);
      // Set new Timer
      call MilliTimer.startOneShot(dt);
      dbg("Timer","Mote #%d: Timer will trigger in %d [ms]\n", TOS_NODE_ID, dt);
    }
    else {
      dbg("Radio", "Mote #%d: ACK for Packet n°%d was not received, resending...\n", TOS_NODE_ID, seq[TOS_NODE_ID - 1]);

      retries[TOS_NODE_ID - 1] += 1;

      sendNextPacket();
    }

    return;
  }
  

  //***************************** Receive interface *****************//
  event message_t* Receive.receive(message_t* buf, void* payload, uint8_t len) {
    /* This event is triggered when a message is received
     *
     * STEPS:
     * 1. Read the content of the message
     * 2. Check if the type is request (REQ)
     * 3. If a request is received, send the response
     * X. Use debug statements showing what's happening (i.e. message fields)
     */
    // BASE STATION ONLY (as long as no RTS/CTS is used)
    my_msg_t* msg;
    float n_tot_tries;

    if (len != sizeof(my_msg_t)) {
      dbg("Radio", "Base Station: Packet received is malformed.\n");

      return buf;
    }

    msg = (my_msg_t*) payload;
    dbg("Radio", "Base Station: Packet n°%d from mote #%d received!\n", msg->seq_num, msg->sender_id);

    // Inspect message and update mote's PER
    n_tot_tries = (1 / (1 - per[msg->sender_id])) * (msg->seq_num - 1);
    per[msg->sender_id] = 1 - msg->seq_num / (n_tot_tries + 1 + msg->n_retries);
    dbg("Radio", "Base Station: Mote #%d has a PER of %.1f%\n", msg->sender_id, per[msg->sender_id] * 100);

    return buf;
  }


  //******************* Functions *****************//
  uint32_t millisToNextPoisson(uint8_t l) {
    float p_unif;
    float int_arr_time;
    float milliLambda = (float) l;
    
    milliLambda = milliLambda / 1000;
    
    p_unif = call Random.rand16();
    p_unif = p_unif / UINT16_MAX;
    
    int_arr_time = -logf(1 - p_unif) / milliLambda;
	
    return (uint32_t) int_arr_time;
  }


  void sendNextPacket() {
	my_msg_t* msg;
  
    do {
      msg = (my_msg_t*) call Packet.getPayload(&packet, sizeof(my_msg_t));
    }
    while (msg == NULL);

    msg->sender_id = TOS_NODE_ID;
    msg->seq_num = seq[TOS_NODE_ID - 1];
    msg->n_retries = retries[TOS_NODE_ID - 1];

    // Set ACK request and send packet to the station
    if (call PacketAcknowledgements.requestAck(&packet) == SUCCESS) {
      if (call AMSend.send(BASE_STATION_ID, &packet, sizeof(my_msg_t)) == SUCCESS) {
        dbg("Timer", "Mote #%d: Packet n°%d sent, waiting for ACK\n", TOS_NODE_ID, msg->seq_num);

        return;
      }
    }

    // If something goes wrong, retry
    dbg("Timer","Mote #%d: Failed to send, retrying...\n");
    sendNextPacket();

    return;
  }



}

