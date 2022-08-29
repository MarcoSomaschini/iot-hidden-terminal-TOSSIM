/**
 *  Configuration file for wiring of sendAckC module to other common 
 *  components needed for proper functioning
 *
 *  @author 
 */

#include "hiddenTerminal.h"

configuration hiddenTerminalAppC {}

implementation {


/****** COMPONENTS *****/
  components MainC, hiddenTerminalC as App;
  // Other components
  components ActiveMessageC;
  components RandomC;
  components new TimerMilliC() as PoissonTimer;
  components new TimerMilliC() as StopTimer;
  components new AMSenderC(AM_MY_MSG);
  components new AMReceiverC(AM_MY_MSG);
  components new FakeSensorC();


/****** INTERFACES *****/
  // Boot interface
  App.Boot -> MainC.Boot;

  /****** Wire the other interfaces down here *****/
  // Send and Receive interfaces
  App.Receive -> AMReceiverC;
  App.AMSend -> AMSenderC;
  // Radio Control
  App.SplitControl -> ActiveMessageC;
  // Interfaces to access package fields
  App.Packet -> AMSenderC;
  // Timer interface
  App.PoissonTimer -> PoissonTimer;
  App.StopTimer -> StopTimer;
  // RNG
  App.Random -> RandomC;
  // ACKS
  App.PacketAcknowledgements -> AMSenderC.Acks;
  // Fake Sensor read
  App.Read -> FakeSensorC;

}

