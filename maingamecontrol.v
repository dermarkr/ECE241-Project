//Main Game Control

module maingamecontrol
		(
			CLOCK_50,						//	On Board 50 MHz
			KEY,  							// On Board Keys
			GPIO_0,
			GPIO_1,
			VGA_CLK,   						//	VGA Clock
			VGA_HS,							//	VGA H_SYNC
			VGA_VS,							//	VGA V_SYNC
			VGA_BLANK_N,						//	VGA BLANK
			VGA_SYNC_N,						//	VGA SYNC
			VGA_R,   						//	VGA Red[9:0]
			VGA_G,	 						//	VGA Green[9:0]
			VGA_B   						//	VGA Blue[9:0]
		);

		input			   CLOCK_50;				//	50 MHz
		input	 [3:0]	KEY;
		input  [5:0]   GPIO_0;
		output [20:0]  GPIO_1;
		output			VGA_CLK;   				//	VGA Clock
		output			VGA_HS;					//	VGA H_SYNC
		output			VGA_VS;					//	VGA V_SYNC
		output			VGA_BLANK_N;			//	VGA BLANK
		output			VGA_SYNC_N;				//	VGA SYNC
		output [7:0]	VGA_R;   				//	VGA Red[7:0] Changed from 10 to 8-bit DAC
		output [7:0]	VGA_G;	 				//	VGA Green[7:0]
		output [7:0]	VGA_B;   				//	VGA Blue[7:0]



		//declaring wires for external inputs
		wire startbutton;
		wire resetn;
		wire closed;
		wire opened;
		
		//assigning external inputs
		assign resetn = KEY[0];
		assign startbutton = ~GPIO_0[0];
		assign closed = ~GPIO_0[1];
		assign opened = ~GPIO_0[2];
		
		//declaring wires for external outputs
		wire [3:0] motorpins;
		
		//assigning external outputs
		assign GPIO_1[3:0] = motorpins[3:0];
		
		//declaring wires for FSM
		wire close, open, rng, prestart, win, ready;
		wire rngcountdone;		
		wire [3:0] current_state;
		wire hand_out;	
		
		//declaring wires for countdown controls
		wire countdone_quarter, countdone_half, countdone_one, countdone_seven, countdone_two, countdone_four;
		wire enable_quarter, enable_half, enable_seven, enable_one, enable_two, enable_four;		
		
		//declaring wires for ramdon number look-up list
		wire [3:0] rngnum;
		wire [32:0] rngnumout;
		wire [4:0] score1, score2, score3; 

		//declaring wires for motorcontrol
		wire jaw_is_open, jaw_is_closed;
		wire [3:0] current;
		wire draw;

		//declaring wires for VGA control
		wire [7:0] x;
		wire [6:0] y;
		wire [23:0] colour;
		wire [3:0] currentVGA;
		
		//Declaring Video output module
		vga_adapter VGA(.resetn(resetn),
							 .clock(CLOCK_50),
							 .colour(colour),
							 .x(x),
							 .y(y),
							 .plot(1),
							 /* Signals for the DAC to drive the monitor. */
							 .VGA_R(VGA_R),
							 .VGA_G(VGA_G),
							 .VGA_B(VGA_B),
							 .VGA_HS(VGA_HS),
							 .VGA_VS(VGA_VS),
							 .VGA_BLANK(VGA_BLANK_N),
							 .VGA_SYNC(VGA_SYNC_N),
							 .VGA_CLK(VGA_CLK));
		defparam VGA.RESOLUTION = "160x120";
		defparam VGA.MONOCHROME = "FALSE";
		defparam VGA.BITS_PER_COLOUR_CHANNEL = 8;
		defparam VGA.BACKGROUND_IMAGE = "StartingBackground.mif";
		
		
		//declaring motorFSM module
		motorFSM m0(.clock(CLOCK_50),
						.resetn(resetn),
						.open_fsm(open),
						.close_fsm(close),
						.limit_jawOpen(opened),
						.limit_jawClose(closed),
						.jaw_is_open(jaw_is_open),
						.jaw_is_closed(jaw_is_closed),
						.pin(motorpins),
						.current(current)
						);
		
		//declaring main game FSM module
		controller c0(.clk(CLOCK_50), 
						  .resetn(resetn), 
						  .startbutton(startbutton),
						  .rngcountdone(rngcountdone),
						  .hand_out(hand_out),
						  .closed(closed),
						  .prestart(prestart),
						  .close(close),
						  .open(open),
						  .rng(rng),
						  .win(win),
						  .ready(ready),
						  .current_state(current_state),
						  .countdone_quarter(countdone_quarter),
						  .countdone_half(countdone_half),
						  .countdone_one(countdone_one),
						  .countdone_two(countdone_two),
						  .countdone_four(countdone_four),
						  .countdone_seven(countdone_seven),
						  .enable_quarter(enable_quarter),
						  .enable_half(enable_half),
						  .enable_one(enable_one),
						  .enable_two(enable_two),
						  .enable_four(enable_four),
						  .enable_seven(enable_seven),
						  .opened(opened)
						  );
						  
		//declaring main game control datapath
		datapath d0(.clk(CLOCK_50),
						.prestart(prestart),
						.win(win),
						.closed(closed),
						.close(close),
						.check(check),
						.score1(score1),
						.score2(score2),
						.score3(score3),
						.hand_out(hand_out),
						.ready(ready)
						);
							
		
		//declaring Video output FSM module
		VGAcontrol VGA0(.clk(CLOCK_50), 
					    .resetn(resetn), 
						 .start(rng),  
						 .score1(score1), 
						 .score2(score2), 
						 .score3(score3),
						 .x_out(x),
						 .y_out(y),
						 .colour_out(colour),
						 .draw(draw),
						 .currentmain(current_state)
						 );
		
		//declaring random number cycling module		
		rng r0(.clk(CLOCK_50),
				 .reset_n(resetn),
				 .rngnum(rngnum)
				 );
		
		//declaring random number lookup table module
		randomnumberlookup r1(.rngnum(rngnum),
									 .rngnumout(rngnumout)
									 );
									
		//declaring countdown from ramdom number module
		rngcountdown c1(.clk(CLOCK_50),
						 .loadEnable(rng),
						 .load(rngnumout),
						 .countDone(rngcountdone)
						 );
		
		//declaring a variety of countdown modules
		countdown_half c2(.clk(CLOCK_50),
						 .loadEnable(enable_half),
						 .countDone(countdone_half)
						 );
					
		countdown_quarter c3(.clk(CLOCK_50),
								  .loadEnable(enable_quarter),
								  .countDone(countdone_quarter)
								  );
								
		countdown_seven c4(.clk(CLOCK_50),
								 .loadEnable(enable_seven),
								 .countDone(countdone_seven)
								 );
								 
		countdown_four c6(.clk(CLOCK_50),
								 .loadEnable(enable_four),
								 .countDone(countdone_four)
								 );
								 
		countdown_two c7(.clk(CLOCK_50),
								 .loadEnable(enable_two),
								 .countDone(countdone_two)
								 );
								 
		countdown_one c8(.clk(CLOCK_50),
								 .loadEnable(enable_one),
								 .countDone(countdone_one)
								 );
																	
endmodule
     
                
//This module is an FSM which acts as the brain of the game
//it determines when the game starts, when the jaw closes
//and if the player won or lost
module controller(
					input clk,
					input resetn,
					input startbutton,
					input rngcountdone, hand_out,
					input closed, opened,
					input countdone_quarter, countdone_half, countdone_one, countdone_two, countdone_four, countdone_seven,
					output reg prestart, close, open, rng, win, ready, gameover,
					output reg enable_quarter, enable_half, enable_one, enable_two, enable_four, enable_seven,
					output reg [3:0] current_state
					);

	reg [3:0] next_state;
   
	//declares states
	localparam  PRESTART		= 4'd0,
					WAIT			= 4'd1,
					CLOSE    	= 4'd2,
					CHECK			= 4'd3,
					WIN			= 4'd4,
					OPEN			= 4'd5,
					AFTERWIN		= 4'd6,
					READY			= 4'd7,
					LOSE        = 4'd8,
					RESETGAME	= 4'd9,
					AFTERLOSE	= 4'd10,
					GAMEOVER		= 4'd11;

	 //this section dictates the order of states and the 
	 //requirements for switching between states
    always@(*)
    begin: state_table
	 case(current_state)
			PRESTART: begin
				if(startbutton) next_state = WAIT;	//checks if startbutton pressed if so goes to WAIT state
			end
			WAIT: begin
				if(rngcountdone)  next_state = CLOSE;   //checks if the random countdown is done if so jaw closes
			end
			CLOSE: begin
				if(countdone_one) next_state = CHECK;   //waits one second as the jaw closes then checks if the jaw has closed
			end
			CHECK: begin
				if(countdone_quarter) begin	//checks if jaws caught hand 
					if(closed || hand_out > 0 ) next_state = WIN;		//closed represents the limit switch if the limit switch is closed the player wins
					else if(!closed) next_state = LOSE;		//If the limit switch is open the player loses
				end
			end
			LOSE: begin
				next_state = RESETGAME;  //continues directly to resetgame
			end
			AFTERLOSE: begin
				if(countdone_two) next_state = GAMEOVER;  //waits 2 seconds then contines to GAMEOVER this is to allow for the You Lose screen to show
			end
			GAMEOVER: begin
				if(countdone_four) next_state = PRESTART; //waits 4 second while showing the GAME OVER screen the goes back to the PRESTART state 
			end
			RESETGAME: begin
				if(opened || countdone_four)	//waits for the jaw to hit the open limit switch or for 4 seconds to protect the motor
				next_state = AFTERLOSE;  //moves to afterlose state
			end
			WIN: begin  
				next_state = OPEN;  //continues directly to open state
			end
			OPEN: begin
				if(opened || countdone_one)	next_state = AFTERWIN;  //Waits For Jaws to open or for 1 second
			end
			AFTERWIN: begin
				if(countdone_two) next_state = READY; //waits 2 seconds while Escaped screen shown
			end
			READY: begin
				if(startbutton) next_state = WAIT; //checks if startbutton pressed if so goes to WAIT state
				else if(countdone_seven) next_state = PRESTART;  //Waits 7 seconds then goes to PRESTART
			end
			default: next_state = PRESTART;
    endcase 
	 end
   
	 //This section dictates what will happen in each state
	 //as well as starting countdowns
    always @(*)
    begin: enable_signals
	 
		prestart 		<= 0;
		rng 				<= 0;
		close 			<= 0;
		open				<= 0;
		win				<= 0;
		ready 			<= 0;
		enable_half 	<= 0;
		enable_quarter <= 0;
		enable_one		<= 0;
		enable_two		<= 0;
		enable_four		<= 0;
		enable_seven 	<= 0;
		
        case (current_state)
				PRESTART: begin	//the prestart state ensures that all game values are in their starting state
					prestart 		<= 1;
					rng 				<= 0;
					close 			<= 0;
					open				<= 0;
					win				<= 0;
					ready 			<= 0;
					enable_half 	<= 0;
					enable_quarter <= 0;
					enable_two		<= 0;
					enable_four		<= 0;
					enable_seven 	<= 0;
				end
				WAIT: begin			//wait begins the ramdon countdown
					prestart 		<= 0;
					rng 				<= 1;
					close 			<= 0;
					open				<= 0;
					win				<= 0;
					ready 			<= 0;
					enable_half 	<= 0;
					enable_quarter <= 0;
					enable_two		<= 0;
					enable_four		<= 0;
					enable_seven 	<= 0;
				end
				CLOSE: begin		//close closes the jaw
					prestart 		<= 0;
					rng 				<= 0;
					close 			<= 1;
					open				<= 0;
					win				<= 0;
					ready 			<= 0;
					enable_half 	<= 0;
					enable_quarter <= 0;
					enable_one		<= 1;
					enable_two		<= 0;
					enable_four		<= 0;
					enable_seven 	<= 0;
            end
				OPEN: begin			//open opens the jaw
					prestart 		<= 0;
					rng 				<= 0;
					close 			<= 0;
					open				<= 1;
					win				<= 0;
					ready 			<= 0;
					enable_half 	<= 0;
					enable_quarter <= 0;
					enable_one		<= 1;
					enable_two		<= 0;
					enable_four		<= 0;
					enable_seven 	<= 0;
				end
				CHECK: begin		//check starts a counter after which the FSM checks if the player won or lost
					prestart 		<= 0;
					rng 				<= 0;
					close 			<= 0;
					open				<= 0;
					win				<= 0;
					ready 			<= 0;
					enable_half 	<= 0;
					enable_quarter <= 1;
					enable_one		<= 0;
					enable_two		<= 0;
					enable_four		<= 0;
					enable_seven 	<= 0;
				end
				WIN: begin			//sends the win signal to the datapath incrementing the score
					prestart 		<= 0;
					rng 				<= 0;
					close 			<= 0;
					open				<= 0;
					win				<= 1;
					ready 			<= 0;
					enable_half 	<= 0;
					enable_quarter <= 0;
					enable_two		<= 0;
					enable_four		<= 0;
					enable_seven 	<= 0;		
				end
				AFTERWIN: begin	//starts 2 second counter for video purposes
					prestart 		<= 0;
					rng 				<= 0;
					close 			<= 0;
					open				<= 0;
					win				<= 0;
					ready 			<= 0;
					enable_half 	<= 0;
					enable_quarter <= 0;
					enable_two		<= 1;
					enable_four		<= 0;
					enable_seven 	<= 0;
				end				
            LOSE: begin	
					prestart 		<= 0;
					rng 				<= 0;
					close 			<= 0;
					open				<= 0;
					win				<= 0;
					ready 			<= 0;
					enable_half 	<= 0;
					enable_quarter <= 0;
					enable_two		<= 0;
					enable_four		<= 0;
					enable_seven 	<= 0;
            end
            AFTERLOSE: begin	//starts the 2 second counter for video purposes
					prestart 		<= 0;
					rng 				<= 0;
					close 			<= 0;
					open				<= 0;
					win				<= 0;
					ready 			<= 0;
					enable_half 	<= 0;
					enable_quarter <= 0;
					enable_two		<= 1;
					enable_four		<= 0;
					enable_seven 	<= 0;
            end
				GAMEOVER: begin	//starts the 4 second timer for video purposes
					prestart 		<= 0;
					rng 				<= 0;
					close 			<= 0;
					open				<= 0;
					win				<= 0;
					ready 			<= 0;
					enable_half 	<= 0;
					enable_quarter <= 0;
					enable_two		<= 0;
					enable_four		<= 1;
					enable_seven 	<= 0;
            end
				RESETGAME: begin	//opens the jaw and satrts 4 second timer
					prestart 		<= 0;
					rng 				<= 0;
					close 			<= 0;
					open				<= 1;
					win				<= 0;
					ready 			<= 0;
					enable_half 	<= 0;
					enable_quarter <= 0;
					enable_two		<= 0;
					enable_four		<= 1;
					enable_seven 	<= 0;
				end
				READY: begin		//sends ready signal to datapath and starts 7 second timer
					prestart 		<= 0;
					rng 				<= 0;
					close 			<= 0;
					open				<= 0;
					win				<= 0;
					ready 			<= 1;
					enable_half 	<= 0;
					enable_quarter <= 0;
					enable_two		<= 0;
					enable_four		<= 0;
					enable_seven 	<= 1;
				end
         endcase
    end // enable_signals
   
	 //sets state transition to clock edge
    always@(posedge clk)
    begin: state_FFs
        if(!resetn)
            current_state = PRESTART;
        else
            current_state = next_state;
    end // state_FFS
endmodule

//the datapath 2 concerned with 2 functions
//1.incrementing the score
//2.ensuring that if the jaw fully closes then opens slightly the player will still win
module datapath(	clk,
						prestart,
						win,	
						closed,
						close,
						check,
						ready,
						score1,
						score2,
						score3,
						hand_out
						);

	input clk;
	input prestart;
	input win;
	input closed;
	input	close;
	input check;
	input ready;
	output reg [4:0] score1, score2, score3;
	output reg hand_out;
	
	//score incrementer
	always@(posedge clk)
	begin
		//sets score to 0 if the game is in prestart state
		if(prestart) begin
			score1 <= 4'b0;
			score2 <= 4'b0;
			score3 <= 4'b0;
		end
		//if the win value is true the score is incremented by one
		//to make graphics display easier the score value is broken 
		//into 3 parts and each is kept between 0-9
		else if(win) begin
			if(score1 < 9) score1 <= score1 + 1;
			else if(score1 == 9) begin
				score1 <= 0;
				if(score2 < 9) score2 <= score2 + 1;
				else if(score2 == 9) begin
					score2 <= 0;
					score3 <= score3 + 1;
				end
			end				
		end
	end
	
	//ensures that if the jaw fully closes then opens slightly the player will still win
	always@(*)
	begin
		//sets handout to 0 after check states is over effectively
		if(prestart || ready)
			hand_out <= 0;
		//sets hand_out to 1 if jaw closes during close or check state
		else if(close || check) begin
			if(closed && hand_out == 0)
				hand_out <= 1;
		end
	end
endmodule


//selects a number based on a 4 bit input
//in this circuit the 4 bit value in being fed in by a constantly cycling counter
module randomnumberlookup( input [3:0]rngnum, output reg[32:0]rngnumout);
			
	always@(*)
	begin
	case(rngnum[3:0])
		4'd0: 	rngnumout = 'd50000000;
		4'd1: 	rngnumout = 'd106250000;
		4'd2: 	rngnumout = 'd134375000;
		4'd3: 	rngnumout = 'd162500000;
		4'd4: 	rngnumout = 'd190625000;
		4'd5: 	rngnumout = 'd218750000;
		4'd6: 	rngnumout = 'd246875000;
		4'd7: 	rngnumout = 'd275000000;
		4'd8: 	rngnumout = 'd303125000;
		4'd9: 	rngnumout = 'd331250000;
		4'd10:	rngnumout = 'd359375000;
		4'd11: 	rngnumout = 'd387500000;
		4'd12: 	rngnumout = 'd415625000;
		4'd13: 	rngnumout = 'd443750000;
		4'd14: 	rngnumout = 'd471875000;
		4'd15: 	rngnumout = 'd500000000;
		default: rngnumout = 'd50000000;
	endcase
	end
endmodule
	
//cycles 4-bit value at clock edge
module rng(input clk, reset_n, output reg [3:0]rngnum);
    always @ (posedge clk) begin
			rngnum <= rngnum + 1;
    end
endmodule

//counts down from loaded in random value
module rngcountdown(clk, load, loadEnable, countDone);
   input clk, loadEnable;
   input [32:0]load;
   output reg countDone;
   
   reg [32:0]countVal;
    
   always @(posedge clk) begin
		//if the loadEnable value is false random value is loaded in
		//(a little confusing i know)
		//and countDone set to zero
		if (!loadEnable) begin
			countVal <= load;
			countDone <= 0;
		end
		
		//when the value is counted down the zero countDone is set to 1
      else if (countVal == 'd0) begin
			countDone <= 1;
		end
		
		//while the value is not zero it is incremented down each clock cycle
		else if(countVal != 'd0) begin
			countVal <= countVal - 1;
			countDone <= 0;
		end
    end
endmodule

//////////////////////////////////////////////////////////////////////////////////////
////////////Collection of counters below only first one will be commented/////////////
//////////////////////////////////////////////////////////////////////////////////////

module countdown_one(clk, loadEnable, countDone);
   input clk, loadEnable;
   output reg countDone;
    
   reg [32:0]countVal;
    
   always @(posedge clk) begin
	//while loadEnable = 0 countval is set to initail value and countDone is set to 0 
   if (!loadEnable) begin
		countVal <= 'd50000000;
		countDone <= 0;
	end

	//when countval is equal to 0 countDone is set to 1
   else if (countVal == 'd0) begin
		countDone <= 1;
	end

	//while countval is not zero it is incremented down each clock cycle
	else if(countVal != 'd0) begin
		countVal <= countVal - 1;
		countDone <= 0;
	end
   end
endmodule


module countdown_half(clk, loadEnable, countDone);
    input clk, loadEnable;
    output reg countDone;
    
    reg [32:0]countVal;
    
    always @(posedge clk) begin
        if (!loadEnable) begin
		countVal <= 'd25000000;
		countDone <= 0;
	end

   else if (countVal == 'd0) begin
		countDone <= 1;
	end

	else if(countVal != 'd0) begin
		countVal <= countVal - 1;
		countDone <= 0;
	end
    end
endmodule

module countdown_quarter(clk, loadEnable, countDone);
    input clk, loadEnable;
    output reg countDone;
    
    reg [32:0]countVal;
    
   always @(posedge clk) begin
        if (!loadEnable) begin
		countVal <= 'd12500000;
		countDone <= 0;
	end

        else if (countVal == 'd0) begin
		countDone <= 1;
	end

	else if(countVal != 'd0) begin
		countVal <= countVal - 1;
		countDone <= 0;
	end
   end
endmodule

module countdown_two(clk, loadEnable, countDone);
    input clk, loadEnable;
    output reg countDone;
    
    reg [32:0]countVal;
    
   always @(posedge clk) begin
        if (!loadEnable) begin
		countVal <= 'd100000000;
		countDone <= 0;
	end

   else if (countVal == 'd0) begin
			countDone <= 1;
	end

	else if(countVal != 'd0) begin
		countVal <= countVal - 1;
		countDone <= 0;
	end
   end
endmodule


module countdown_four(clk, loadEnable, countDone);
    input clk, loadEnable;
    output reg countDone;
    
    reg [32:0]countVal;
    
   always @(posedge clk) begin
        if (!loadEnable) begin
		countVal <= 'd200000000;
		countDone <= 0;
	end

   else if (countVal == 'd0) begin
			countDone <= 1;
	end

	else if(countVal != 'd0) begin
		countVal <= countVal - 1;
		countDone <= 0;
	end
   end
endmodule


module countdown_seven(clk, loadEnable, countDone);
    input clk, loadEnable;
    output reg countDone;
    
    reg [32:0]countVal;
    
   always @(posedge clk) begin
        if (!loadEnable) begin
		countVal <= 'd750000000;
		countDone <= 0;
	end

   else if (countVal == 'd0) begin
			countDone <= 1;
	end

	else if(countVal != 'd0) begin
		countVal <= countVal - 1;
		countDone <= 0;
	end
   end
endmodule
