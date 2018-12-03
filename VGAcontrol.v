//VGA control module

module VGAcontrol(clk, 
				resetn, 
				start, 
				score1, 
				score2, 
				score3,
				x_out,
				y_out,
				colour_out,
				draw,
				currentmain
				);
				
	input resetn;
	input clk;
	input start;
	input [3:0] score1, score2, score3;
	input [3:0] currentmain;
	output [7:0] x_out;
	output [6:0] y_out;
	output [23:0] colour_out;
	output draw;
	
	//declares wires for drawcontrol
	wire countdone;	
	wire draw_done;
	wire countstart;
	wire [3:0] current;
	wire pre;
	
	//declares wires for drawdatapath	
	wire [23:0] imagedata;
	wire [17:0] address_start;
	wire [11:0] num1_start, num2_start, num3_start;
	wire [23:0] numberdata1, numberdata2, numberdata3;	
	wire [7:0] x_counter;
	wire [6:0] y_counter;
	wire [7:0] x_out;
	wire [6:0] y_out;
	wire [17:0] address;
	
	
	wire [11:0] num1address, num2address, num3address;
	wire [8:0] pixel;
	
	//pixel describes the position of the pixel being drawn in 20x20 blocks at the top of the screen
	//this is used with num#_start to determine which part of the rom should be accessed 
	//used to draw the score numbers
	assign pixel = (y_counter * 20) + x_counter + 2;
	
	//look_up table module to find address start value using score values
	numberSelect l1(.num_select(score1), .address_num(num1_start));
	numberSelect l2(.num_select(score2), .address_num(num2_start));
	numberSelect l3(.num_select(score3), .address_num(num3_start));
	
	//assigns the address to access the rom using the pixel value and start value from lookup table
	assign num1address = num1_start + pixel;
	assign num2address = num2_start + pixel;
	assign num3address = num3_start + pixel;
	
	//pulls colour data from rom based on num#address
	ROMnumbers ROM1(.address(num1address), .clock(clk), .q(numberdata1));
	ROMnumbers ROM2(.address(num2address), .clock(clk), .q(numberdata2));
	ROMnumbers ROM3(.address(num3address), .clock(clk), .q(numberdata3));	
	
	wire [17:0] imageaddress;
	
	//gets rom address start position based on FSM output
	backSelect back1(.back_select(current), .address_back(address_start));
	
	//calculates current draw position based on y_out and x_out values
	assign imageaddress = address_start + ((y_out - 20) * 160) + x_out + 3;

	//pulls colour data from rom based on imageaddress
	ROMbackground ROM0(.address(imageaddress), .clock(clk), .q(imagedata));
	
	//declares fsm for the video output
	drawcontrol dc(.clk(clk),
						.resetn(resetn),
						.start(start),
						.pre(pre),
						.countdone(countdone),
						.draw_done(draw_done),
						.draw(draw),
						.countstart(countstart),
						.current(current),
						.currentmain(currentmain));
	
	//declares datapath for the video output		
	drawdatapath(	.clk(clk), 
						.resetn(resetn), 
						.pre(pre),
						.draw(draw),
						.imagedata(imagedata),
						.numberdata1(numberdata1),
						.numberdata2(numberdata2),
						.numberdata3(numberdata3),
						.colour_out(colour_out),
						.x_out(x_out),
						.y_out(y_out),
						.address(address),
						.draw_done(draw_done),
						.x_counter(x_counter),
						.y_counter(y_counter)
						);

	//declares 2 second countdown module
	countdown_2 cd3(.clk(clk), .loadEnable(countstart), .countDone(countdone));

endmodule


//the drawcontrol module is the FSM for the Video Output
//it uses the state of the main FSM to determine which image should be shown
module drawcontrol(clk, 
						resetn,
						start, 
						pre,
						countdone,
						draw_done,
						draw,
						countstart,
						current,
						currentmain);
					
	input clk;
	input resetn;
	input start;
	input countdone;
	input draw_done;
	input [3:0] currentmain;
	output reg pre;
	output reg countstart;
	output reg draw;
	output reg [3:0] current;

	reg [3:0] next;

	//declares states
	localparam	HOLD				= 'd0,
					DRAW_PRE			= 'd1,
					DRAW_START		= 'd2,
					DRAW_WIN			= 'd3,
					DRAW_LOSE		= 'd4,
					DRAW_GAMEOVER	= 'd5,
					DRAW_PRE_HAND 	= 'd6,
					DRAW_PRE_WAIT	= 'd7,
					DRAW_START_WAIT= 'd8,
					DRAW_WIN_WAIT  = 'd9,
					DRAW_LOSE_WAIT = 'd10,
					DRAW_GAMEOVER_WAIT = 'd11,
					DRAW_PRE_HAND_WAIT = 'd12;
					
	//this section dictates the order of states and the 
	//requirements for switching between states				
	always@(*)
	begin
	case(current)
		HOLD: begin
			if (currentmain == 'd0 || currentmain == 'd7) next = DRAW_PRE; //If the main state is PRESTART or READY goes to DRAW_PRE
			else if (start) next = DRAW_START; //if start is true goes to DRAW_START
			end
		DRAW_PRE: begin
			if (draw_done) next = DRAW_PRE_WAIT; //after drawing is done goes to DRAW_PRE_WAIT state 
			else if (currentmain == 'd8 || currentmain == 'd10) next = DRAW_LOSE; //If the main state is LOSE or AFTERLOSE goes to DRAW_LOSE
		end
		DRAW_PRE_WAIT:begin
			if (countdone) next = DRAW_PRE_HAND; //after 2 seconds goes to DRAW_PRE_HAND
			else if (start) next = DRAW_START;//if start is true goes to DRAW_START
			else if (currentmain == 'd8 || currentmain == 'd10) next = DRAW_LOSE; //If the main state is LOSE or AFTERLOSE goes to DRAW_LOSE
		end
		DRAW_PRE_HAND: begin
			if(draw_done) next = DRAW_PRE_HAND_WAIT; //after drawing is done goes to DRAW_PRE_HAND_WAIT state 
			else if (currentmain == 'd8 || currentmain == 'd10) next = DRAW_LOSE; //If the main state is LOSE or AFTERLOSE goes to DRAW_LOSE
		end
		DRAW_PRE_HAND_WAIT: begin
			if (countdone) next = DRAW_PRE;  //after 2 seconds goes to DRAW_PRE
			else if (start) next = DRAW_START;//if start is true goes to DRAW_START
			else if (currentmain == 'd8 || currentmain == 'd10) next = DRAW_LOSE; //If the main state is LOSE or AFTERLOSE goes to DRAW_LOSE
		end
		DRAW_START: begin
			if(draw_done) next = DRAW_START_WAIT; //after drawing is done goes to DRAW_START_WAIT state 
			else if (currentmain == 'd8 || currentmain == 'd10) next = DRAW_LOSE; //If the main state is LOSE or AFTERLOSE goes to DRAW_LOSE
		end
		DRAW_START_WAIT: begin
			if(currentmain == 'd4) next = DRAW_WIN; //after 2 seconds goes to DRAW_WIN
			else if (currentmain == 'd8 || currentmain == 'd10) next = DRAW_LOSE; //If the main state is LOSE or AFTERLOSE goes to DRAW_LOSE
		end
		DRAW_WIN: begin
			if(draw_done) next = DRAW_WIN_WAIT; //after drawing is done goes to DRAW_WIN_WAIT state 
		end
		DRAW_WIN_WAIT: begin
			if(countdone) next = DRAW_PRE;  //after 2 seconds goes to DRAW_PRE
			else if (currentmain == 'd0 || currentmain == 'd7) next = DRAW_PRE; //If the main state is PRESTART or READY goes to DRAW_PRE
			else if (start) next = DRAW_START;//if start is true goes to DRAW_START
		end
		DRAW_LOSE: begin
			if(draw_done) next = DRAW_LOSE_WAIT; //after drawing is done goes to DRAW_LOSE_WAIT state 
		end
		DRAW_LOSE_WAIT: begin 
			if(countdone) next = DRAW_GAMEOVER;  //after 2 seconds goes to DRAW_GAMEOVER
			else if (currentmain == 'd0 || currentmain == 'd7) next = DRAW_PRE; //If the main state is PRESTART or READY goes to DRAW_PRE
			else if (start) next = DRAW_START; //if start is true goes to DRAW_START
		end
		DRAW_GAMEOVER: begin
			if(draw_done) next = DRAW_GAMEOVER_WAIT; //after drawing is done goes to DRAW_GAMEOVER_WAIT state 
		end
		DRAW_GAMEOVER_WAIT: begin
			if (currentmain == 'd0 || currentmain == 'd7) next = DRAW_PRE; //If the main state is PRESTART or READY goes to DRAW_PRE
		end
		default: next = HOLD;
	endcase
	end	
		
	//sets the draw and countstart values for each state determining when drawing happens and when to wait
	//pre value is set as well and used in drawdatapath to reset values
	always@(*)
	begin
		pre				<= 0;
		countstart		<= 0;
		draw				<= 1;
	case(current)
		HOLD: begin
			pre				<= 1;
			countstart		<= 0;
			draw				<= 1;
		end
		DRAW_PRE: begin
			pre				<= 0;
			countstart		<= 1;
			draw				<= 1;
		end
		DRAW_PRE_WAIT: begin
			pre				<= 0;
			countstart		<= 0;
			draw				<= 0;
		end
		DRAW_PRE_HAND: begin
			pre				<= 0;
			countstart		<= 0;
			draw				<= 1;
		end
		DRAW_PRE_HAND_WAIT: begin
			pre				<= 0;
			countstart		<= 1;
			draw				<= 0;
		end
		DRAW_START: begin
			pre				<= 0;
			draw				<= 1;
		end
		DRAW_START_WAIT: begin
			pre				<= 0;
			countstart		<= 1;
			draw				<= 0;
		end
		DRAW_WIN: begin
			pre				<= 0;
			countstart		<= 0;
			draw				<= 1;
		end
		DRAW_WIN_WAIT: begin
			pre				<= 0;
			countstart		<= 1;
			draw				<= 0;
		end
		DRAW_LOSE: begin
			pre				<= 0;
			countstart		<= 0;
			draw				<= 1;
		end
		DRAW_LOSE_WAIT: begin
			pre				<= 0;
			countstart		<= 1;
			draw				<= 0;
		end
		DRAW_GAMEOVER: begin
			pre				<= 0;
			countstart		<= 0;
			draw				<= 1;
		end
		DRAW_GAMEOVER_WAIT: begin
			pre				<= 0;
			countstart		<= 1;
			draw				<= 0;
		end
	endcase
	end

	//sets state transition to clock edge
	always@(posedge clk)
	begin
	if(!resetn)
		current = HOLD;
	else
		current = next;
	end
	
endmodule


//the drawdatapath is used to set the draw location and give it a colour
module drawdatapath(	clk, 
							resetn, 
							pre,
							draw,
							imagedata,
							numberdata1,
							numberdata2,
							numberdata3,
							colour_out,
							x_out,
							y_out,
							address,
							draw_done,
							x_counter,
							y_counter
							);
	
	input clk;
	input resetn;
	input pre;
	input draw;
	input [23:0] imagedata;
	input [23:0] numberdata1;
	input [23:0] numberdata2;
	input [23:0] numberdata3;
	output reg [23:0] colour_out;
	output reg [7:0] x_out;
	output reg [6:0] y_out;
	output reg [16:0] address;
	output reg draw_done;
	output reg [7:0] x_counter;
	output reg [6:0] y_counter;
	
	//x and y denote the start position for each destinct drawing cell
	reg [7:0] x;
	reg [6:0] y;
	
	always@(posedge clk)
	begin
	
	//combines start positions and their respective counters
	x_out <= x + x_counter;
	y_out <= y + y_counter;
	
		//resets values to 0 when pre is true
		if(pre) begin
			x <= 0;
			y <= 0;
			x_counter <= 0;
			y_counter <= 0;
			x_out <= 0;
			y_out <= 0;
			draw_done <= 0;
		end
		
		if(draw) begin
			
			//sets colour output for the first 20 rows with the last 3 20x20 square displaying the score
			if(x == 0 && y == 0) colour_out <= 'b0;
			else if(x == 20 && y == 0) colour_out <= 'b0;
			else if(x == 40 && y == 0) colour_out <= 'b0;
			else if(x == 60 && y == 0) colour_out <= 'b0;
			else if(x == 80 && y == 0) colour_out <= 'b0;
			else if(x == 100 && y == 0) colour_out <= numberdata3;
			else if(x == 120 && y == 0) colour_out <= numberdata2;
			else if(x == 140 && y == 0) colour_out <= numberdata1;
			//sets colour output for the rest of the display
			else if(y == 20) begin
				colour_out <= imagedata;
			end
	
			//increments draw location through the first 20 rows
			//it increments x 20 pixels then increments y by 1
			//when y and x get to the bottom right corner of the 20x20 square
			//it moves to the top left of the next square
			//after the row of squares is done y is set to 20 and the main image is drawn
			if(y == 0) begin
				if(x_counter < 18) begin
					x_counter <= x_counter + 1;
				end
				else if(x_counter == 18) begin
					x_counter <= 0;
					if(y_counter < 19) y_counter <= y_counter + 1;
					else begin
						x_counter <= 0;
						y_counter <= 0;
						if(x < 160) x <= x + 20;
						else begin
							y<=20;
							x<=0;
							x_counter <= 0;
							y_counter <= 0;
						end
					end
				end
			end
			
			
			//when y == 20 the drawn pixels are incremented across the display and at the end moved down by one
			else if(y == 20) begin
				x <= 0;
				y <= 20;
				if(x_counter < 159) begin
					x_counter <= x_counter + 1;
				end
				else if(x_counter == 159) begin
					x_counter <= 0;
					if(y_counter < 100) y_counter <= y_counter + 1;
					else begin
						draw_done <= 1;
						x <= 0;
						y <= 0;
					end
				end
				
			end		
				
			
			
		end
		else begin 
			x <= 0;
			y <= 0;
			x_counter <= 0;
			y_counter <= 0;
			x_out <= 0;
			y_out <= 0;
			draw_done <= 0;
		end
	end
		
	
endmodule

//selects the starting address to draw the main image base on the FSM output
module backSelect(back_select, address_back);
	input [3:0] back_select;
	output reg [17:0] address_back;

	always@(*)
	begin
		case(back_select)
			4'd0		:	address_back = 'd0;				//HOLD
			4'd1		:	address_back = 'd0;				//PRE
			4'd2		:	address_back = 'd16000;			//START
			4'd3		:	address_back = 'd32000;			//WIN
			4'd4		:	address_back = 'd48000;			//LOSE
			4'd5		:	address_back = 'd64000;			//GAMEOVER
			4'd6		:	address_back = 'd16000;			//DRAW_PRE_HAND
			4'd7		:	address_back = 'd0;				//PRE
			4'd8		:	address_back = 'd16000;			//START
			4'd9		:	address_back = 'd32000;			//WIN
			4'd10		:	address_back = 'd48000;			//LOSE
			4'd11		:	address_back = 'd64000;			//GAMEOVER
			4'd12		:	address_back = 'd16000;			//DRAW_PRE_HAND
			default	:	address_back = 'd0;				//0 
		endcase
	end
	
	endmodule

//selects the starting address to draw the number for each score digit based 
//on score inputs from the main game datapath
module numberSelect(num_select, address_num);
	input [4:0] num_select;
	output reg [11:0] address_num;

	always@(*)
	begin
		case(num_select)
			4'b0000		:	address_num = 'd0;				//0
			4'b0001		:	address_num = 'd400;				//1
			4'b0010		:	address_num = 'd800;				//2
			4'b0011		:	address_num = 'd1200;			//3
			4'b0100		:	address_num = 'd1600;			//4
			4'b0101		:	address_num = 'd2000;			//5
			4'b0110		:	address_num = 'd2400;			//6
			4'b0111		:	address_num = 'd2800;			//7
			4'b1000		:	address_num = 'd3200;			//8
			4'b1001		:	address_num = 'd3600;			//9
			default	:	address_num = 'd0;				//0 
		endcase
	end

	endmodule

	//2 second countdown clock
module countdown_2(clk, loadEnable, countDone);
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