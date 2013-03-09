
#include "Timer.h"
#include "Flooding.h"
 


module FloodingC {
  uses {
    interface Boot;
    interface Receive;
    interface AMSend;
    interface Timer<TMilli> as MilliTimer;
    interface SplitControl as AMControl;
    interface Packet;
    interface Random;
  }
}
implementation {

  nx_uint16_t nodes[NODES];
  nx_uint16_t nodes2[NODES];
 
  message_t packet;

  uint16_t message = 0;
	
  uint16_t cont = 0;

  uint16_t i;


  event void Boot.booted() {

      
    dbg("Boot", "Node %hhu booted\n", TOS_NODE_ID);
    call AMControl.start();
    for (i=0; i<NODES; ++i) {
        nodes[i] = 0;
    }
   
    
    
  }

  // C'è un tempo da attendere prima che la radio
  // finisca di avviarsi. Quando ha finito di attivarsi
  // viene generato l'evento startDone. Qui parte
  // l'applicazione vera e propria
  event void AMControl.startDone(error_t err) {
    if (err == SUCCESS) {
      call MilliTimer.startOneShot(500); // all'incirca (tinyos usa la base 2) 1 sec = 1024 msec
    }
    else {
      call AMControl.start(); // proviamo a farla ripartire
    }
  }

  event void AMControl.stopDone(error_t err) {
    // do nothing
  }
  
  event void MilliTimer.fired() {
	//scaduto il timer creo la locazione del pkt da inviare e incremento il payload del messaggio
      radio_count_msg_t* rcm = (radio_count_msg_t*)call Packet.getPayload(&packet, (int) NULL);
      	
	//incremento il num di sequenza nel vettore nodes[mia_posizione] 
      nodes[TOS_NODE_ID]++;

      //creo il pacchetto da inviare
      rcm->message = message;
      rcm->id = TOS_NODE_ID;
      rcm->seq = nodes[TOS_NODE_ID];

	
     if (TOS_NODE_ID == SOURCE_NODE) { //il messaggio viene generato e inviato solo dal nodo 1; gli altri possono solo rinoltrarlo
	if (call AMSend.send(AM_BROADCAST_ADDR, &packet, sizeof(radio_count_msg_t)) == SUCCESS) {
		dbg("Inoltro", "Pacchetto inviato id=%hhu seq=%hhu message=%hhu\n", rcm->id, rcm->seq, rcm->message);
	}
      }
    }
  

  event message_t* Receive.receive(message_t* bufPtr, void* payload, uint8_t len) {
	
	if (len != sizeof(radio_count_msg_t)) {return bufPtr;} // se la dim non è 16byte ignoriamo il pacchetto
	else {
        // Punto al payload del pacchetto ricevuto
        radio_count_msg_t* rcm = (radio_count_msg_t*)payload;
        // Punto al payload del nuovo pacchetto
        radio_count_msg_t* rcm2 = (radio_count_msg_t*)call Packet.getPayload(&packet, (int) NULL); 

       	dbg("Ricevuti", "Ricevuto Pacchetto id=%hhu seq=%hhu message=%hhu\n", rcm->id, rcm->seq, rcm->message);
	if(MAXRIC!=0){
	if(rcm->id!=TOS_NODE_ID){
        	if(nodes[rcm->id]==rcm->seq){
			++nodes2[rcm->id];
			if(nodes2[rcm->id] < MAXRIC){
			 	rcm2->id = rcm->id;
			 	rcm2->seq = rcm->seq;
	 			rcm2->message = rcm->message;
		 		if (call AMSend.send(AM_BROADCAST_ADDR, &packet, sizeof(radio_count_msg_t)) == SUCCESS) {
		 	  		dbg("Inoltro", "Pacchetto inoltrato id=%hhu seq=%hhu message=%hhu\n", rcm->id, rcm->seq, rcm->message);
		 		}
			}
			else dbg("Scarti", "Pacchetto scartato id=%hhu seq=%hhu message=%hhu\n", rcm->id, rcm->seq, rcm->message);
		}
		else if(nodes[rcm->id]>rcm->seq) dbg("Scarti", "Pacchetto scartato id=%hhu seq=%hhu message=%hhu\n", rcm->id, rcm->seq, rcm->message);
		else {
			nodes[rcm->id] = rcm->seq;  // Aggiorno il numero di sequenza
			nodes2[rcm->id] = 0;

			rcm2->id = rcm->id;
			rcm2->seq = rcm->seq;
	 		rcm2->message = rcm->message;
		 	if (call AMSend.send(AM_BROADCAST_ADDR, &packet, sizeof(radio_count_msg_t)) == SUCCESS) {
		 		dbg("Inoltro", "Pacchetto inoltrato id=%hhu seq=%hhu message=%hhu\n", rcm->id, rcm->seq, rcm->message);
		 	}
		}
	}
	}
	else{
		nodes[rcm->id] = rcm->seq;  // Aggiorno il numero di sequenza
		nodes2[rcm->id] = 0;
		rcm2->id = rcm->id;
		rcm2->seq = rcm->seq;
		rcm2->message = rcm->message;
		if (call AMSend.send(AM_BROADCAST_ADDR, &packet, sizeof(radio_count_msg_t)) == SUCCESS) {
	  		dbg("Inoltro", "Pacchetto inoltrato id=%hhu seq=%hhu message=%hhu\n", rcm->id, rcm->seq, rcm->message);
		}
	}

	
        return bufPtr;
    }
  }

  event void AMSend.sendDone(message_t* bufPtr, error_t error) {
	
    if (&packet == bufPtr) {  // controlliamo che è esattamente il pacchetto che stavamo trasmettendo
    }
		
  }

}
