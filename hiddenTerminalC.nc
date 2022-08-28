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

bool csma_busy = FALSE;
bool stop = FALSE;

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
    interface Timer<TMilli> as StopTimer;
    interface Timer<TMilli> as PoissonTimer;
    interface Timer<TMilli> as WaitTimer;

    //other interfaces, if needed
    interface Random;
    interface PacketAcknowledgements;
    
    // Interface used to perform sensor reading (to get the value from a sensor)
    interface Read<uint16_t>;

  }

} implementation {

  // SENDER MOTES
  // Lambda associated with the motes
  uint8_t lambda;
  uint8_t n_retries = 0;
  uint16_t seq_num = 1;

  uint8_t nb = 0;
  uint8_t be = 0;

  bool cts;
  bool waiting == FALSE;
  bool busy == FALSE;

  // BASE_STATION
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
      cts = TRUE;

      // After STOP_TIME print motes stats and stop accetting packets
      call StopTimer.startOneShot(STOP_INT * 1000);
    }
    else {
      // The other nodes are SENDER MOTES
      cts = FALSE;

      // Set Poisson lambda
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
      call PoissonTimer.startOneShot(dt);
    }
  }

  
  event void SplitControl.stopDone(error_t err){
    /* Fill it ... */
  }


  //***************** Timer interface ********************//
  event void PoissonTimer.fired() {
    if (stop == TRUE) {
      return;
    }

    // Generate and send packet
    sendNextPacket();
  }


  event void WaitTimer.fired() {
    // MOTES ONLY
    busy = FALSE;

    if (waiting == TRUE) {
      waiting = FALSE;

      sendNextPacket();
    }
  }


  event void StopTimer.fired() {
    // BASE STATION: Log motes transmissions stats and terminate operations
    uint8_t id;

    for (id = 2; id < 7; id++) {
      dbg("Timer","Base Station: Mote #%d AVG transmissions is %f [msg/s]\n", id, mote_seq_num[id - 2] / STOP_INT);
    }
    for (id = 2; id < 7; id++) {
      float psr = (float) mote_seq_num[id - 2] / mote_trans[id - 2];

      dbg("Timer", "Base Station: Mote #%d has a PER of %.1f%\n", id, (1 - psr) * 100);
    }

    stop = TRUE;
  }
  

  //********************* AMSend interface ****************//
  event void AMSend.sendDone(message_t* buf, error_t err) {
    // MOTES ONLY (as long as no RTS/CTS is used)
    uint32_t dt;

    // Wait for ACK, resend if not acked
    if (call PacketAcknowledgements.wasAcked(buf) == TRUE) {
      dbg("Radio", "Mote #%d: ACK for Packet n°%d received!\n", TOS_NODE_ID, seq_num);

      seq_num++;
      n_retries = 0;
      if (TOS_NODE_ID % 2 == 0) {
        busy = FALSE;

        nb = 0;
        be = 0;
    }

      // Simulate new inter-arrival time
      dt = millisToNextPoisson(lambda);
      // Set new Timer
      call PoissonTimer.startOneShot(dt);
    }
    else {
      dbg("Radio", "Mote #%d: ACK for Packet n°%d was not received, resending...\n", TOS_NODE_ID, seq_num);

      n_retries++;
      if (TOS_NODE_ID % 2 == 0) {
        busy = FALSE;

        nb = 0;
        be = 0;
    }

      sendNextPacket();
    }

    return;
  }
  

  //***************************** Receive interface *****************//
  event message_t* Receive.receive(message_t* buf, void* payload, uint8_t len) {
    my_msg_t* req;
    my_msg_t* resp;

    req = (my_msg_t*) payload;

    if (TOS_NODE_ID == BASE_STATION_ID) {
      switch (req->type) {
        case RTS:
          // Send CTS
          if (cts == FALSE) {
            return;
          }
          dbg("Radio", "Base Station: RTS received from mote #%d\n", req->sender_id);

          do {
            resp = (my_msg_t*) call Packet.getPayload(&packet, sizeof(my_msg_t));
          }
          while (resp == NULL);

          resp->type = CTS;
          resp->sender_id = req->sender_id;

          if (call AMSend.send(AM_BROADCAST_ADDR, &packet, sizeof(my_msg_t)) == SUCCESS) {
            cts = FALSE;
            call WaitTimer.startOneShot(WAIT_INT)
            return;
          }
          break;

        case DATA:
          // Process data
          dbg("Radio", "Base Station: Packet n°%d from mote #%d received!\n", req->seq_num, req->sender_id);
          call Read.read();

          if (msg->seq_num == mote_seq_num[msg->sender_id - 2]) {
            dbg("Radio", "Base Station: Packet received is a duplicate.\n");

            mote_trans[msg->sender_id - 2]++;
          }
          else {
            mote_seq_num[msg->sender_id - 2] = msg->seq_num;
            mote_trans[msg->sender_id - 2] += msg->n_retries + 1;
          }

          cts = TRUE;
          break;
      }
    }
    else {
      switch (req->type) {
        case RTS:
          // Some mote is trying to sync with the base, wait
          busy = TRUE;

          call WaitTimer.startOneShot(WAIT_INT);
          break;

        case CTS:
          if (req->sender_id == TOS_NODE_ID) {
            // The base answered, send packet
            call WaitTimer.stop()
            cts == TRUE;

            sendNextPacket()
          }
          else {
            // Some mote was granted transmission right, wait
            busy = TRUE;

            call WaitTimer.startOneShot(WAIT_INT);
          }
          break;
      }
    }

    return;
  }
  
  
  //************************* Read interface **********************//
  event void Read.readDone(error_t result, uint16_t data) {
    // Do nothing, only used to simulate some packet computation (waste time)
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
    uint16_t n_periods;
    uint16_t p_unif;
    uint32_t backoff_time;
  	my_msg_t* msg;

    if (busy == TRUE) {
      dbg("Timer", "Mote #%d: Channel is busy, backing off...\n", TOS_NODE_ID);

      call PoissonTimer.startOneShot(WAIT_INT);
      return;
    }

    if (TOS_NODE_ID % 2 == 0) {
      if (csma_busy == FALSE) {
        csma_busy = TRUE;
      }
      else {
        dbg("Timer", "Mote #%d: Channel is busy, backing off...\n", TOS_NODE_ID);

        nb++;
        if (be < MAXBE) {
          be++;
        }

        p_unif = call Random.rand16();
        n_periods = (p_unif % (uint16_t) pow(2, be)) + 1;
        backoff_time = (uint32_t) BACKOFFPERIOD * n_periods;

        call PoissonTimer.startOneShot(backoff_time);
        return;
      }
    }
  
    do {
      msg = (my_msg_t*) call Packet.getPayload(&packet, sizeof(my_msg_t));
    }
    while (msg == NULL);

    msg->sender_id = TOS_NODE_ID;
    msg->seq_num = seq_num;
    msg->n_retries = n_retries;

    if (cts == FALSE) {
      // Send RTS in broadcast
      msg->type = RTS;

      if (call AMSend.send(AM_BROADCAST_ADDR, &packet, sizeof(my_msg_t)) == SUCCESS) {
        dbg("Timer", "Mote #%d: RTS sent, waiting for response...\n", TOS_NODE_ID, msg->seq_num);
        waiting = TRUE;

        call WaitTimer.startOneShot(WAIT_INT);
        return;
      }
    }
    else {
      // Set ACK request and send packet to the station
      if (call PacketAcknowledgements.requestAck(&packet) == SUCCESS) {
        if (call AMSend.send(BASE_STATION_ID, &packet, sizeof(my_msg_t)) == SUCCESS) {
          dbg("Timer", "Mote #%d: Packet n°%d sent, waiting for ACK\n", TOS_NODE_ID, msg->seq_num);
          cts = FALSE;

          return;
        }
      }
    }

  }



}

