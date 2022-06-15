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

  // SENDER MOTES
  // Lambda associated with the motes
  uint8_t lambda;
  uint8_t n_retries = 0;
  uint16_t seq_num = 1;

  // BASE_STATION
  uint8_t counter = 0;
  // Current sequence number of each mote
  uint16_t mote_seq_num[] = {0, 0, 0, 0, 0};
  uint16_t mote_trans[] = {0, 0, 0, 0, 0};
  
  message_t packet;

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
      // Every LOG_INTERVAL (10) secs print motes stats
      call MilliTimer.startPeriodic(LOG_INTERVAL * 1000);
    }
    else {
      // The other nodes are SENDER MOTES
      switch (TOS_NODE_ID) {
        case 2:
          lambda = LAMBDA_1;
          break;
        case 3:
          lambda = LAMBDA_2;
          break;
        case 4:
          lambda = LAMBDA_3;
          break;
        case 5:
          lambda = LAMBDA_4;
          break;
        case 6:
          lambda = LAMBDA_5;
          break;
      }

      // Generate first inter-arrival time according to mote's lambda
      dt = millisToNextPoisson(lambda);

      // Set first Timer to start routine
      call MilliTimer.startOneShot(dt);
    }
  }

  
  event void SplitControl.stopDone(error_t err){
    /* Fill it ... */
  }


  //***************** MilliTimer interface ********************//
  event void MilliTimer.fired() {
    if (TOS_NODE_ID == BASE_STATION_ID) {
      uint8_t id;
      float time_elapsed;

      counter++;
      time_elapsed = (float) counter * LOG_INTERVAL;

      for (id = 2; id < 7; id++) {      
        dbg("Timer","Base Station: Mote #%d AVG transmissions is %f [msg/s]\n", id, mote_seq_num[id - 2] / time_elapsed);
      }
      for (id = 2; id < 7; id++) {
      	float psr = (float) mote_seq_num[id - 2]/mote_trans[id - 2];
      
        dbg("Timer", "Base Station: Mote #%d has a PER of %.1f%\n", id, (1 - psr) * 100);
      }
    }
    else {
      // Generate and send packet
      sendNextPacket();
    }
  }
  

  //********************* AMSend interface ****************//
  event void AMSend.sendDone(message_t* buf,error_t err) {
    // MOTES ONLY (as long as no RTS/CTS is used)
    uint32_t dt;

    // Wait for ACK, resend if not acked
    if (call PacketAcknowledgements.wasAcked(buf) == TRUE) {
      dbg("Radio", "Mote #%d: ACK for Packet n°%d received!\n", TOS_NODE_ID, seq_num);

      seq_num++;
      n_retries = 0;

      // Simulate new inter-arrival time
      dt = millisToNextPoisson(lambda);
      // Set new Timer
      call MilliTimer.startOneShot(dt);
    }
    else {
      dbg("Radio", "Mote #%d: ACK for Packet n°%d was not received, resending...\n", TOS_NODE_ID, seq_num);

      n_retries++;

      sendNextPacket();
    }

    return;
  }
  

  //***************************** Receive interface *****************//
  event message_t* Receive.receive(message_t* buf, void* payload, uint8_t len) {
    // BASE STATION ONLY (as long as no RTS/CTS is used)
    my_msg_t* msg;

    if (len != sizeof(my_msg_t)) {
      dbg("Radio", "Base Station: Packet received is malformed.\n");

      return buf;
    }

    // Inspect message and update mote's PER
    msg = (my_msg_t*) payload;
    dbg("Radio", "Base Station: Packet n°%d from mote #%d received!\n", msg->seq_num, msg->sender_id);

    if (msg->seq_num == mote_seq_num[msg->sender_id - 2]) {
      dbg("Radio", "Base Station: Packet received is a duplicate.\n");

      // What if the duplicate has a different number of retries?
      mote_trans[msg->sender_id - 2]++;
    }
    else {
      mote_seq_num[msg->sender_id - 2] = msg->seq_num;
      mote_trans[msg->sender_id - 2] += msg->n_retries + 1;
    }

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
    msg->seq_num = seq_num;
    msg->n_retries = n_retries;

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

