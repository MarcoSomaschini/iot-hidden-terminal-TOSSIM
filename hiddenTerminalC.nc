/**
 *  Source file for implementation of module hiddenTerminal
 *
 *  @author Marco Somaschini 10561636
 */

#include "hiddenTerminal.h"
#include "Timer.h"
#include <math.h>

// Indicates if the shared channel is free, only used by even numbered motes (2, 4, 6)
bool csma_busy = FALSE;
// Indicates if the base station is accepting transmissions
bool stop = FALSE;

module hiddenTerminalC {

  uses {
	interface Boot;
	
  // Interfaces for communication
  interface Receive;
  interface AMSend;
  interface SplitControl;
  interface Packet;

  // Interfaces for timers
  interface Timer<TMilli> as PoissonTimer;
  interface Timer<TMilli> as WaitTimer;
  interface Timer<TMilli> as StopTimer;

  // Other interfaces
  interface Random;
  interface PacketAcknowledgements;

  // Interface used to perform sensor reading (to get the value from a sensor)
  interface Read<uint16_t>;

  }

} implementation {

  // SENDER MOTES
  // Lambda associated with the motes
  uint8_t lambda;
  // Current packet parameters
  uint8_t n_retries = 0;
  uint16_t seq_num = 1;

  // CSMA related variables, only used by even numbered motes (2, 4, 6)
  uint8_t nb = 0;
  uint8_t be = 0;

  // Indicates if the mote has sent an RTS and thus is waiting for a CTS
  bool waiting = FALSE;
  // Indicates if the mote has received an RTS/CTS and thus should stall transmissions
  bool busy = FALSE;

  // BASE_STATION
  // Current sequence number of each mote
  uint16_t mote_seq_num[] = {0, 0, 0, 0, 0};
  uint16_t mote_trans[] = {0, 0, 0, 0, 0};

  // Indicates if the mote has received a CTS and can transmit
  // Indicates if the base station hasn't received an RTS
  bool cts;

  // OTHERS
  message_t packet;

  // Poisson simulation function
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
          lambda = LAMBDA_2;
          break;
        case 3:
          lambda = LAMBDA_3;
          break;
        case 4:
          lambda = LAMBDA_4;
          break;
        case 5:
          lambda = LAMBDA_5;
          break;
        case 6:
          lambda = LAMBDA_6;
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
  	if (stop == TRUE) {
      return;
    }  
  
    if (TOS_NODE_ID == BASE_STATION_ID) {
      // BASE STATION: The mote which sent the RTS didn't follow on, thus cts flag is reset to allow others to sync
      dbg("Timer","Base Station: After CTS, nothing was received.\n");
      cts = TRUE;
    }
    else {
      // SENDER MOTES
      // In any case, after the stall time has expired the channel has to be considered free
      busy = FALSE;

      if (waiting == TRUE) {
        // If the mote was waiting for the CTS, sent another RTS
        dbg("Timer","Mote #%d: CTS was not received, retrying...\n", TOS_NODE_ID);
        waiting = FALSE;

        sendNextPacket();
      }
      else {
      	dbg("Timer","Mote #%d: Timer expired, stop stalling.\n", TOS_NODE_ID);
      }
    }
  }


  event void StopTimer.fired() {
    // BASE STATION: Log motes transmissions stats and terminate operations
    uint8_t id;

    dbg("Timer","\n");
    dbg("Timer","\n");
    dbg("Timer","!END OF TRANSMISSIONS!\n");
    dbg("Timer","\n");
    dbg("Timer","\n");

    for (id = 2; id < 7; id++) {
      dbg("Timer","Base Station: Mote #%d AVG transmission rate is %f [msg/s]\n", id, (float) mote_seq_num[id - 2] / STOP_INT);
    }
    for (id = 2; id < 7; id++) {
      float psr = (float) mote_seq_num[id - 2] / mote_trans[id - 2];

      dbg("Timer","Base Station: Mote #%d has a PER of %.1f%\n", id, (1 - psr) * 100);
    }

    stop = TRUE;
  }
  

  //********************* AMSend interface ****************//
  event void AMSend.sendDone(message_t* buf, error_t err) {
    uint32_t dt;
    
    if (TOS_NODE_ID == BASE_STATION_ID) {
    	return;
    }
    
    if (waiting == TRUE) {
    	return;
    }
    
    cts = FALSE;

    // Wait for packet ACK, resend if not acked
    if (call PacketAcknowledgements.wasAcked(buf) == TRUE) {
      dbg("Radio", "Mote #%d: ACK for Packet n°%d received!\n", TOS_NODE_ID, seq_num);

      seq_num++;
      n_retries = 0;
      // Even motes need to restore CSMA params
      if (TOS_NODE_ID % 2 == 0) {
        csma_busy = FALSE;

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

      // Increase number of retries for this packet
      n_retries++;
      if (TOS_NODE_ID % 2 == 0) {
        csma_busy = FALSE;

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
      // BASE STATION
      switch (req->type) {
        case RTS:
          // Upon receiving an RTS, send a CTS
          // If a mote RTS is already being handled, ignore
          if (cts == FALSE) {
            return buf;
          }
          dbg("Radio", "Base Station: RTS received from mote #%d\n", req->sender_id);

          do {
            resp = (my_msg_t*) call Packet.getPayload(&packet, sizeof(my_msg_t));
          }
          while (resp == NULL);

          resp->type = CTS;
          resp->sender_id = req->sender_id;

          // Send CTS in broadcast
          if (call AMSend.send(AM_BROADCAST_ADDR, &packet, sizeof(my_msg_t)) == SUCCESS) {
            cts = FALSE;
            call WaitTimer.startOneShot(WAIT_INT);
            return buf;
          }
          break;

        case DATA:
          // Process data
          call WaitTimer.stop();
          
          dbg("Radio", "Base Station: Packet n°%d from mote #%d received!\n", req->seq_num, req->sender_id);
          // Process packet
          call Read.read();

          // Update mote trasmissions status
          if (req->seq_num == mote_seq_num[req->sender_id - 2]) {
            dbg("Radio", "Base Station: Packet received is a duplicate.\n");

            mote_trans[req->sender_id - 2]++;
          }
          else {
            mote_seq_num[req->sender_id - 2] = req->seq_num;
            mote_trans[req->sender_id - 2] += req->n_retries + 1;
          }

          cts = TRUE;
          break;
      }
    }
    else {
      // SENDER MOTES
      switch (req->type) {
        case RTS:
          // Some mote is trying to sync with the base station, stall
          dbg("Timer", "Mote #%d: A RTS was received, stalling...\n", TOS_NODE_ID);
          busy = TRUE;

          call WaitTimer.startOneShot(WAIT_INT);
          break;

        case CTS:
          if (req->sender_id == TOS_NODE_ID) {
            // The base station answered, send packet
            dbg("Timer", "Mote #%d: Base Station answered with a CTS!, sending...\n", TOS_NODE_ID);
            call WaitTimer.stop();
            cts = TRUE;
            waiting = FALSE;

            sendNextPacket();
          }
          else {
            // Some mote was granted transmission right, stall
            dbg("Timer", "Mote #%d: A CTS was received, stalling...\n", TOS_NODE_ID);
            busy = TRUE;

            call WaitTimer.startOneShot(WAIT_INT);
          }
          break;
      }
    }

    return buf;
  }
  
  
  //************************* Read interface **********************//
  event void Read.readDone(error_t result, uint16_t data) {
    // Does nothing: only used to simulate some packet computation (waste time)
  }


  //******************* Functions *****************//
  uint32_t millisToNextPoisson(uint8_t l) {
    float p_unif;
    float int_arr_time;
    float milliLambda = (float) l;
    
    milliLambda = milliLambda / 1000;

    // Generate random number between 0 and 1
    p_unif = call Random.rand16();
    p_unif = p_unif / UINT16_MAX;

    // Compute time to next packet according to a Poisson distribution
    int_arr_time = -logf(1 - p_unif) / milliLambda;
	
    return (uint32_t) int_arr_time;
  }


  void sendNextPacket() {
    uint16_t n_periods;
    uint16_t p_unif;
    uint32_t backoff_time;
  	my_msg_t* msg;

    // EVEN MOTES: Check if the channel is busy
    if (TOS_NODE_ID % 2 == 0) {
      if (csma_busy == FALSE) {
        // If the channel is free, occupy it
      	if (cts == TRUE && busy == FALSE) {
          csma_busy = TRUE;
      	}
      }
      else {
        // Otherwise, back off
        dbg("Timer", "Mote #%d: Channel is busy, backing off...\n", TOS_NODE_ID);

        nb++;
        if (be < MAXBE) {
          be++;
        }

        // Generate number of backoff periods between [0, 2^be - 1]
        p_unif = call Random.rand16();
        n_periods = (p_unif % (uint16_t) pow(2, be)) + 1;
        backoff_time = (uint32_t) BACKOFFPERIOD * n_periods;

        call PoissonTimer.startOneShot(backoff_time);
        return;
      }
    }

    // Delay the timer if the mote is stalling
    if (busy == TRUE) {
      dbg("Timer", "Mote #%d: Channel is busy, waiting...\n", TOS_NODE_ID);
      
      call PoissonTimer.startOneShot(WAIT_INT);
      return;
    }

    // Prepare the message
    do {
      msg = (my_msg_t*) call Packet.getPayload(&packet, sizeof(my_msg_t));
    }
    while (msg == NULL);

    msg->sender_id = TOS_NODE_ID;
    msg->seq_num = seq_num;
    msg->n_retries = n_retries;

    // Obtain the transmissions rights
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
      msg->type = DATA;
      
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

