//*********************************TOP MODULE*********************************************************//

//-----variable names::----------------------------------------------------------------------------------//
//open_fsm and close_fsm are signals to open and close coming from the central game control
//limit_jawOpen: limit switch that indicates if jaw is open when depressed (similar for limit_jawClose)
//jaw_is_open and jaw_is_closed are "handshakes" back to the main game control

//---potential bugs:-------------------------------------------------------------------------------------//
//counter that is used to slow the motor
//signal may not get thru to the FPGA since there is no initial value for countVal

module motorFSM(clock, resetn, open_fsm, close_fsm, limit_jawOpen, limit_jawClose, jaw_is_open, jaw_is_closed, pin, current);

    input clock, resetn, open_fsm, close_fsm, limit_jawOpen, limit_jawClose;
    output jaw_is_open, jaw_is_closed;
    output [3:0]pin;
    
    wire openJaw, closeJaw, counterClock;
	 output [3:0] current;
    
    //everytime the countDone == 1 --> rising edge of the counterClock
    //counterClock used to slow down the motor
    countdown_motor countdown_motor(.clock(clock), .countDone(counterClock));

    controlMotor controlMotor1(.clock(clock),
                               .resetn(resetn), 
                                .open_fsm(open_fsm), 
                                .close_fsm(close_fsm),
                                .limit_jawOpen(limit_jawOpen), 
                                .limit_jawClose(limit_jawClose), 
                                .openJaw(openJaw), 
                                .closeJaw(closeJaw), 
                                .jaw_is_open(jaw_is_open), 
                                .jaw_is_closed(jaw_is_closed),
										  .current(current));
    
        
    datapathMotor datapathMotor1(.counterClock(counterClock), 
                                .resetn(resetn), 
                                .openJaw(openJaw), 
                                .closeJaw(closeJaw), 
                                .pin(pin));
endmodule













//reset will be connected to the reset that exists in all of the modules
//reset doesn't do anything...mostly for modelsim purposes

module controlMotor(clock, resetn, open_fsm, close_fsm, limit_jawOpen, limit_jawClose, openJaw, closeJaw, jaw_is_open, jaw_is_closed, current) ;
    
    input clock, resetn, open_fsm, close_fsm; //open_fsm and close_fsm: signals from central game control that tells this module what to do
    input limit_jawOpen, limit_jawClose; //limit switches to detect if jaw is open or closed
    
    output reg openJaw, closeJaw; //to control the motor
    output reg jaw_is_closed, jaw_is_open; //"handshake" for the central game control
    
    //state registers
    output reg[3:0] current;
	 reg [3:0] next;
    
    //hold state is to allow time for the central game control to check game status (aka if hand is caught or not)
    //should recieve signal from central game control to open back up the jaws
    localparam READY = 4'd0,
					CLOSE = 4'd1, 
					HOLD  = 4'd2,
					OPEN  = 4'd3;
    
    //state table
    always @(*)
    begin: state_table
		case(current)
			READY: begin
            if (close_fsm) next = CLOSE;	//goes to CLOSE state if close signal recieved
				else if(open_fsm) next = OPEN; //goes to OPEN state if open signal recieved
			end      
			CLOSE: begin
            if (limit_jawClose) next = READY; //returns to READY if when jaw is closed
				else if(open_fsm) next = OPEN;	//goes to OPEN if open signal recieved
			end     
			OPEN: begin
            if (limit_jawOpen) next = READY;  //returns to READY if when jaw is opened
			end
			default: next = READY;
		endcase
    end
    
    //datapath controls
    always @ (*)
    begin: enable_signals
        closeJaw = 'd0;
        openJaw = 'd0;
        jaw_is_closed = 'd0;
        jaw_is_open = 'd0;
        
        case (current)
            READY: begin
                closeJaw = 'd0;
                openJaw = 'd0;
                jaw_is_closed = 'd0;
                jaw_is_open = 'd1;
            end
            
            CLOSE: begin
                closeJaw = 'd1;
                openJaw = 'd0;
                jaw_is_closed = 'd0;
                jaw_is_open = 'd0;
            end
            
            HOLD: begin
                closeJaw = 'd0;
                openJaw = 'd0;
                jaw_is_closed = 'd1;
                jaw_is_open = 'd0;
            end
            
            OPEN: begin
                closeJaw = 'd0;
                openJaw = 'd1;
                jaw_is_closed = 'd0;
                jaw_is_open = 'd0;
            end
        endcase
    end
    
    //current state registers
    always @ (posedge clock) 
        begin
            if (!resetn) current <=READY;
            else current <= next;
        end

endmodule


//there will be a feedback loop to see which pins were last triggered
module datapathMotor(counterClock, resetn, openJaw, closeJaw, pin);

    input counterClock, resetn, openJaw, closeJaw;
    output reg [3:0]pin;
	 
	 reg [3:0]even_odd;
    
    // //output to pins also stored in wires
    // wire [3:0]p;
    
    always @ (posedge counterClock) begin
        even_odd <= even_odd + 1;
		  
		  if (!resetn) begin
            pin[3:0] <= 'd0;
        end
		  
		  
        
        else if (closeJaw) begin
            case (pin[3:0])
                4'b1100: pin = 4'b0110;
                4'b0110: pin = 4'b0011;
                4'b0011: pin = 4'b1001;
                4'b1001: pin = 4'b1100;
                default: pin = 4'b1100;
            endcase
        end
        
		  
		  
		  else if (openJaw) begin
				if(even_odd == 0 || even_odd == 3 || even_odd == 6 || even_odd == 9 || even_odd == 12) begin
					case (pin[3:0])
						 4'b0011: pin = 4'b0110;
						 4'b0110: pin = 4'b1100;
						 4'b1100: pin = 4'b1001;
						 4'b1001: pin = 4'b0011;
						 default: pin = 4'b0011;
					endcase
			  end
		  end
        
        //when the motor shouldnt be stimulated
        else begin
            case (pin[3:0])
                4'b1100: pin = 4'b0000;
                4'b0110: pin = 4'b0000;
                4'b0011: pin = 4'b0000;
                4'b1001: pin = 4'b0000;
					 default: pin = 4'b0000;
            endcase
        end
        
    end    
endmodule

//motor clock....values need to be changed
//potential bugs in here...not sure if resetn is needed? **********************
module countdown_motor(clock, countDone);
    input clock;
    output reg countDone;
    
    reg [32:0]countVal;
    
    always @(posedge clock) begin
        if (countVal == 'd0) begin
            countVal <= 'd100000; //change values as needed
		      countDone <= 1;
	    end

	    else if(countVal != 'd0) begin
		    countVal <= countVal - 1;
		    countDone <= 0;
	    end
    end
endmodule
