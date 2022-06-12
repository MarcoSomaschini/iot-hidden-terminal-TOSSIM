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
  components new TimerMilliC();


/****** INTERFACES *****/
  // Boot interface
  App.Boot -> MainC.Boot;

  /****** Wire the other interfaces down here *****/
  // Send and Receive interfaces
  // Radio Control
  App.SplitControl -> ActiveMessageC;
  // Interfaces to access package fields
  // Timer interface
  App.MilliTimer -> TimerMilliC;
  // RNG
  App.Random -> RandomC;

}

