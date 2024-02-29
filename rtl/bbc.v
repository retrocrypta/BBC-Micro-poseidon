`timescale 1ns / 1ps

module bbc(

	input		    CLK48M_I,
	input       RESET_I,

	input       MODEL_I,

	output      HSYNC,
	output      VSYNC,

	output      VIDEO_CLKEN, 
	output      VIDEO_R,
	output      VIDEO_G,
	output      VIDEO_B,
	output      VIDEO_DE,

	// RAM Interface (CPU)
	output [15:0] MEM_ADR,
	output        MEM_WE,
	output [7:0]  MEM_DO,
	input  [7:0]  MEM_DI,
	output [7:0]  ROMSEL,
	output        SHADOW_RAM,
	output        SHADOW_VID,
	output        ACC_Y,

	output        MEM_SYNC,   // signal to synchronite sdram state machine
	output        PHI0,

	// Keyboard interface
	input         PS2_CLK,
	input         PS2_DAT,

	// audio signal.
	output [15:0]	AUDIO_L,
	output [15:0]	AUDIO_R,

	// externally pressed "shift" key for autoboot
	input         SHIFT,

	output        SDSS,
	output        SDCLK,
	output        SDMOSI,
	input         SDMISO,

	// analog joystick input 
	input [1:0]	 	joy_but,
	input [7:0] 	joy0_axis0,
	input [7:0] 	joy0_axis1,
	input [7:0] 	joy1_axis0,
	input [7:0] 	joy1_axis1,

	// boot settings
	input [7:0]		DIP_SWITCH,

	//FDC signals
	input         img_mounted, // signaling that new image has been mounted
	input  [31:0] img_size,    // size of image in bytes
	input         img_ds,      // SSD/DSD file
	output [31:0] sd_lba,
	output        sd_rd,
	output        sd_wr,
	input         sd_ack,
	input   [8:0] sd_buff_addr,
	input   [7:0] sd_dout,
	output  [7:0] sd_din,
	input         sd_dout_strobe,

	//CMOS RAM
	input  [63:0] RTC,
	input   [5:0] cmos_addr,
	input         cmos_we,
	input   [7:0] cmos_di,
	output  [7:0] cmos_do
);

wire   master = MODEL_I;

// let sdram state machine synchronize to cpu
assign MEM_SYNC = cpu_clken;
assign ROMSEL = romsel;
assign ACC_Y = acc_y;
assign PHI0 = cpu_phi0;
assign VIDEO_DE = crtc_de;
assign SHADOW_VID = acc_d;

wire 		  ram_we;

//  ROM select latch
reg  [7:0] romsel;

// clock enable signals

wire mhz4_clken;
wire mhz2_clken;
wire mhz1_clken;

wire ttxt_clken;
wire ttxt_clkenx2;
wire tube_clken;

wire cpu_clken;
wire cpu_cycle;
wire cpu_phi0;

// decode signals
wire    ddr_enable;

wire    ram_enable; 
wire    rom_enable; 
wire    mos_enable; 

wire    io_fred; 
wire    io_jim; 
wire    io_sheila; 

// SHEILA
wire     crtc_enable; 
wire     acia_enable; 
wire     serproc_enable; 
wire     vidproc_enable; 
wire     romsel_enable; 
wire     acccon_enable; 
wire     sys_via_enable; 
wire     user_via_enable; 
wire     fddc_enable;
wire     fdc_enable;
wire     fdcon_enable; 
wire     adlc_enable; 
wire     adc_enable; 
wire     tube_enable;
wire 	   mhz1_enable;

//  CPU signals
//  6502
localparam CPU_MODE = 2'd0; 
wire    cpu_ready = 1'b 1;
wire    cpu_abort_n = 1'b 1;
wire    cpu_nmi_n;
wire    cpu_so_n = 1'b 1; 
wire    cpu_irq_n;
wire    cpu_r_nw; 
wire    cpu_we; 
wire    cpu_sync;

wire    [23:0] cpu_a; 
wire    [7:0] cpu_di; 
wire    [7:0] cpu_do; 

//  CRTC signals
wire    crtc_clken; 
wire    crtc_clken_adr; 
wire    [7:0] crtc_do; 
wire    crtc_de; 
wire    crtc_cursor; 
reg     crtc_lpstb; 
wire    [13:0] crtc_ma; 
wire    [4:0] crtc_ra; 

//  Decoded display address after address translation for hardware
//  scrolling
reg     [14:0] display_a; 

//  "VIDPROC" signals
wire    vidproc_invert_n; 
wire    vidproc_disen;  

// ADC signals
wire    [7:0] adc_do; 

//  SAA5050 signals
wire    ttxt_glr; 
wire    ttxt_dew; 
wire    ttxt_crs; 
wire    ttxt_lose; 
wire    ttxt_r; 
wire    ttxt_g; 
wire    ttxt_b; 

//  Must loop back output pins or keyboard won't work
wire [3:0] keyb_column = sys_via_pa_out[3:0]; 
wire [2:0] keyb_row = sys_via_pa_out[6:4]; 
wire    keyb_out; 
wire    keyb_int; 
wire    keyb_break;
reg     keyb_reset;
wire    keyb_dip;

// internal reset signals
wire    reset_n = ~RESET_I & ~keyb_reset;

//  IC32 latch on System VIA
reg     [7:0] ic32; 
wire    sound_enable_n; 
wire    speech_read_n; 
wire    speech_write_n; 
wire    keyb_enable_n; 
wire    [1:0] disp_addr_offs; 
wire    caps_lock_led_n; 
wire    shift_lock_led_n; 

//  Sound generator
wire    sound_ready;
wire    [7:0] sound_di;
wire    [7:0] sound_ao;

//  System VIA signals
wire    [7:0] sys_via_do;
wire    sys_via_irq; 
wire    sys_via_ca1_in;
wire    sys_via_ca2_in;
wire    sys_via_ca2_out;
wire    sys_via_ca2_oe;
wire    [7:0] sys_via_pa_in;
wire    [7:0] sys_via_pa_out;
wire    [7:0] sys_via_pa_oe;
wire    sys_via_cb1_in; 
wire    sys_via_cb1_out; 
wire    sys_via_cb1_oe; 
wire    sys_via_cb2_in; 
wire    sys_via_cb2_out; 
wire    sys_via_cb2_oe; 
wire    [7:0] sys_via_pb_in; 
wire    [7:0] sys_via_pb_out; 
wire    [7:0] sys_via_pb_oe; 

//  User VIA signals
wire    [7:0] user_via_do;
wire    user_via_irq;
reg     user_via_ca1_in;
reg     user_via_ca2_in;
wire    user_via_ca2_out;
wire    user_via_ca2_oe;
wire    [7:0] user_via_pa_in;
wire    [7:0] user_via_pa_out;
wire    [7:0] user_via_pa_oe;
wire     user_via_cb1_in;
wire     user_via_cb1_out;
wire     user_via_cb1_oe;
wire     user_via_cb2_in;
wire     user_via_cb2_out;
wire     user_via_cb2_oe;
wire     [7:0] user_via_pb_in;
wire     [7:0] user_via_pb_out;
wire     [7:0] user_via_pb_oe;

// 0xFE34 Access Control (Master)
wire     [7:0] acccon = { acc_irr, acc_tst, acc_ifj, acc_itu, acc_y, acc_x, acc_e, acc_d };
reg      acc_irr;
reg      acc_tst;
reg      acc_ifj;
reg      acc_itu;
reg      acc_y;
reg      acc_x;
reg      acc_e;
reg      acc_d;

reg      vdu_op; // last opcode was 0xC000-0xDFFF

// Master Real Time Clock / CMOS RAM
wire     [7:0] rtc_adi;
wire     [7:0] rtc_do;
wire     rtc_ce;
wire     rtc_r_nw;
wire     rtc_as;
wire     rtc_ds;

// FDC1770
wire     fdc_irq;
wire     fdc_drq;
wire     [7:0] fdc_do;
reg      [3:0] floppy_drive;
reg      floppy_side;
reg      floppy_density;
reg      floppy_reset;
wire 		floppy_motor;

// MMC
// SDCLK is driven from either PB1 or CB1 depending on the SR Mode
wire   sdclk_int = user_via_pb_oe[1] ? user_via_pb_out[1] : 
						(user_via_cb1_oe ? user_via_cb1_out : 1'b1);
assign SDCLK = sdclk_int;
assign user_via_cb1_in = sdclk_int;
// SDMOSI is always driven from PB0
assign SDMOSI = user_via_pb_oe[0] ? user_via_pb_out[0] : 1'b1;
// SDMISO is always read from CB2
assign user_via_cb2_in = SDMISO;
assign SDSS = 0;

// calulation for display address

reg     [3:0]  process_3_aa; 

// Basic Clock Generation

clocks CLOCKS(

	.clk_48m			( CLK48M_I	), // master clock
	.reset_n			( reset_n	),
	
	.vid_clken		( VIDEO_CLKEN		),
	
	.mhz4_clken		( mhz4_clken	),
	.mhz2_clken		( mhz2_clken	),
	.mhz1_clken		( mhz1_clken	),

	.mhz1_enable	( mhz1_enable	),

	.cpu_cycle		( cpu_cycle		),
	.cpu_clken		( cpu_clken		),
	.cpu_phi0     ( cpu_phi0    ),

	.ttxt_clken		( ttxt_clken	),
	.ttxt_clkenx2	( ttxt_clkenx2	),

	.tube_clken		( tube_clken	)
);

address_decode ADDRDECODE(
	.model(MODEL_I),
	.cpu_a(cpu_a),
	.romsel(romsel),
	.ddr_enable(ddr_enable),
	.ram_enable(ram_enable),
	.rom_enable(rom_enable),
	.mos_enable(mos_enable),
	.io_fred(io_fred), 
	.io_jim(io_jim),
	.io_sheila(io_sheila),
	.crtc_enable(crtc_enable),
	.acia_enable(acia_enable),
	.serproc_enable(serproc_enable),
	.vidproc_enable(vidproc_enable),     
	.romsel_enable(romsel_enable),
	.acccon_enable(acccon_enable),
	.sys_via_enable(sys_via_enable),
	.user_via_enable(user_via_enable),
	.fddc_enable(fddc_enable),
	.fdc_enable(fdc_enable),
	.fdcon_enable(fdcon_enable),
	.adlc_enable(adlc_enable),
	.adc_enable(adc_enable),
	.tube_enable(tube_enable),
	.mhz1_enable(mhz1_enable)
);

wire  [7:0] cpu6502_do;
wire [15:0] cpu6502_a;
wire        cpu6502_r_nw;
wire        cpu6502_sync;

T65 CPU6502 (
	.Mode   (CPU_MODE),
	.Res_n  (reset_n),
	.Enable (cpu_clken),
	.Clk    (CLK48M_I),
	.Rdy    (cpu_ready),
	.Abort_n(cpu_abort_n),
	.NMI_n  (cpu_nmi_n),
	.IRQ_n  (cpu_irq_n),
	.SO_n   (cpu_so_n),
	.R_W_n  (cpu6502_r_nw),
	.Sync   (cpu6502_sync),

	.DI     (cpu_di),
	.DO     (cpu6502_do),
	.A      (cpu6502_a)
);

wire  [7:0] cpu65c02_do;
wire [15:0] cpu65c02_a;
wire        cpu65c02_r_nw;
wire        cpu65c02_sync;

R65C02 CPU65C02 (
	.reset  (reset_n),
	.enable (cpu_clken),
	.clk    (CLK48M_I),
	.nmi_n  (cpu_nmi_n),
	.irq_n  (cpu_irq_n),
	.nwe    (cpu65c02_r_nw),
	.sync   (cpu65c02_sync),

	.di     (cpu_di),
	.do     (cpu65c02_do),
	.addr   (cpu65c02_a)
);

assign cpu_r_nw = master ? cpu65c02_r_nw : cpu6502_r_nw;
assign cpu_do = master ? cpu65c02_do : cpu6502_do;
assign cpu_a = master ? cpu65c02_a : cpu6502_a;
assign cpu_sync = master ? cpu65c02_sync : cpu6502_sync;

via6522 SYS_VIA (
	 .clock       (CLK48M_I),
	 .rising      (mhz2_clken &  mhz1_clken),
	 .falling     (mhz2_clken & ~mhz1_clken),
	 .reset       (~reset_n),

	 .addr        (cpu_a[3:0]),
	 .wen         (sys_via_enable & ~cpu_r_nw),
	 .ren         (sys_via_enable &  cpu_r_nw),
	 .data_in     (cpu_do),
	 .data_out    (sys_via_do),

    //-- pio --
	 .port_a_i    (sys_via_pa_in),
	 .port_a_o    (sys_via_pa_out),
	 .port_a_t    (sys_via_pa_oe),

	 .port_b_i    (sys_via_pb_in),
	 .port_b_o    (sys_via_pb_out),
	 .port_b_t    (sys_via_pb_oe),

    //-- handshake pins
	 .ca1_i       (sys_via_ca1_in),

	 .ca2_i       (sys_via_ca2_in),
	 .ca2_o       (sys_via_ca2_out),
	 .ca2_t       (sys_via_ca2_oe),

	 .cb1_i       (sys_via_cb1_in),
	 .cb1_o       (sys_via_cb1_out),
	 .cb1_t       (sys_via_cb1_oe),

	 .cb2_i       (sys_via_cb2_in),
	 .cb2_o       (sys_via_cb2_out),
	 .cb2_t       (sys_via_cb2_oe),

	 .irq         (sys_via_irq)
);

via6522 USER_VIA (
	 .clock       (CLK48M_I),
	 .rising      (mhz2_clken &  mhz1_clken),
	 .falling     (mhz2_clken & ~mhz1_clken),
	 .reset       (~reset_n),

	 .addr        (cpu_a[3:0]),
	 .wen         (user_via_enable & ~cpu_r_nw),
	 .ren         (user_via_enable &  cpu_r_nw),
	 .data_in     (cpu_do),
	 .data_out    (user_via_do),

    //-- pio --
	 .port_a_i    (user_via_pa_in),
	 .port_a_o    (user_via_pa_out),
	 .port_a_t    (user_via_pa_oe),

	 .port_b_i    (user_via_pb_in),
	 .port_b_o    (user_via_pb_out),
	 .port_b_t    (user_via_pb_oe),

    //-- handshake pins
	 .ca1_i       (user_via_ca1_in),

	 .ca2_i       (user_via_ca2_in),
	 .ca2_o       (user_via_ca2_out),
	 .ca2_t       (user_via_ca2_oe),

	 .cb1_i       (user_via_cb1_in),
	 .cb1_o       (user_via_cb1_out),
	 .cb1_t       (user_via_cb1_oe),

	 .cb2_i       (user_via_cb2_in),
	 .cb2_o       (user_via_cb2_out),
	 .cb2_t       (user_via_cb2_oe),

	 .irq         (user_via_irq)
);

//  Keyboard	
keyboard KEYB (	

	 .CLOCK			( CLK48M_I		),
	 .nRESET			( ~RESET_I		),
	 .CLKEN_1MHZ	( mhz1_clken	),
	 .PS2_CLK		( PS2_CLK		),
	 .PS2_DATA		( PS2_DAT		),
	 .AUTOSCAN		( keyb_enable_n),
	 .COLUMN			( keyb_column	),
	 .ROW				( keyb_row		),
	 .KEYPRESS		( keyb_out		),
	 .INT				( keyb_int		),
	 .SHIFT        ( SHIFT        ),
	 .BREAK_OUT		( keyb_break	),
	 .DIP_SWITCH	( DIP_SWITCH	)
);

// sync keyboard reset
always @(posedge CLK48M_I)
	if (cpu_clken) keyb_reset <= keyb_break;

adc ADC (
	 .CLOCK(CLK48M_I),
	 .CLKEN(crtc_clken),
	 .nRESET(reset_n),
	 .ENABLE(adc_enable),
	 .R_nW(cpu_r_nw),
	 .A(cpu_a[1:0]),
	 .DI(cpu_do),
	 .DO(adc_do),

	 // adc is used for analog joystick input 
	 .ch0 ( joy0_axis0 ),
	 .ch1 ( joy0_axis1 ),
	 .ch2 ( joy1_axis0 ),
	 .ch3 ( joy1_axis1 )
);

mc6845 CRTC (
	 .CLOCK(CLK48M_I),
	 .CLKEN(crtc_clken),
	 .nRESET(reset_n),
	 .ENABLE(crtc_enable),
	 .R_nW(cpu_r_nw),
	 .RS(cpu_a[0]),
	 .DI(cpu_do),
	 .DO(crtc_do),
	 .VSYNC	(VSYNC),
	 .HSYNC  (HSYNC),
	 .DE(crtc_de),
	 .CURSOR(crtc_cursor),
	 .LPSTB(crtc_lpstb),
	 .MA(crtc_ma),
	 .RA(crtc_ra)
);

// no sound in the simulator.
`ifndef SIM
sn76489_top SOUND (
		 .clock_i		( CLK48M_I		),
		 .clock_en_i	( mhz4_clken	),
		 .res_n_i		( reset_n		),
		 .ce_n_i			( 1'b 0			),
		 .we_n_i			( sound_enable_n	),
		 .ready_o		( sound_ready	),
		 .d_i				( sound_di		),
		 .aout_o			( sound_ao		)
);
`endif

vidproc VIDEO_ULA (
		.CLOCK(CLK48M_I),
		.CLKEN(VIDEO_CLKEN),
		.nRESET(reset_n),
		.CLKEN_CRTC(crtc_clken),
		.ENABLE(vidproc_enable),
		.A0(cpu_a[0]),
		.DI_CPU(cpu_do),
		.DI_RAM(MEM_DI[7:0]),
		.nINVERT(vidproc_invert_n),
		.DISEN(vidproc_disen),
		.CURSOR(crtc_cursor),
		
		.R_IN		( ttxt_r		),
		.G_IN		( ttxt_g		),
		.B_IN		( ttxt_b		),
		
		.R			( VIDEO_R	),
		.G			( VIDEO_G	),
		.B			( VIDEO_B 	)
);

saa5050 TELETEXT (

	.CLOCK    ( CLK48M_I     ),
	.CLKEN    ( ttxt_clkenx2 ),
	.nRESET   ( reset_n      ),

	//  Data input is synchronised to the main cpu bus clock.
	.DI_CLOCK ( CLK48M_I     ),
	.DI_CLKEN ( mhz4_clken & ~mhz2_clken ),
	.DI       ( MEM_DI[6:0]  ),

	.GLR      ( ttxt_glr     ),
	.DEW      ( ttxt_dew     ),
	.CRS      ( ttxt_crs     ),
	.LOSE     ( ttxt_lose    ),

	.R        ( ttxt_r       ),
	.G        ( ttxt_g       ),
	.B        ( ttxt_b       )
);

initial begin : via_init   

   user_via_ca1_in = 1'b 0;
   user_via_ca2_in = 1'b 0;
   crtc_lpstb = 1'b 0;

end

// rom select latch
always @(posedge CLK48M_I) begin 

	if (!reset_n) begin
		romsel <= 0;
		ic32 <= 0;
	end else begin

		case (sys_via_pb_out[2:0])

			0: ic32[0] <= sys_via_pb_out[3];
			1: ic32[1] <= sys_via_pb_out[3];
			2: ic32[2] <= sys_via_pb_out[3];
			3: ic32[3] <= sys_via_pb_out[3];
			4: ic32[4] <= sys_via_pb_out[3];
			5: ic32[5] <= sys_via_pb_out[3];
			6: ic32[6] <= sys_via_pb_out[3];
			7: ic32[7] <= sys_via_pb_out[3];

		endcase 

		if (romsel_enable & !cpu_r_nw) begin
			romsel <= cpu_do;
			if (!master) romsel[7] <= 0;
		end

	end
end

// RTC/CMOS (Master)
// RTC/CMOS is controlled from the system
// PB7 -> address strobe (AS) active high
// PB6 -> chip enable (CE) active high
// PB3..0 drives IC32 (4-16 line decoder)
// IC32(2) -> data strobe (active high)
// IC32(1) -> read (1) / write (0)

rtc RTC_i (
	.clk(CLK48M_I),
	.cpu_clken(cpu_clken),
	.hard_reset_n(reset_n),
	.reset_n(reset_n),
	.ce(rtc_ce),
	.as(rtc_as),
	.ds(rtc_ds),
	.r_nw(rtc_r_nw),
	.adi(rtc_adi),
	.do(rtc_do),
	.keyb_dip(keyb_dip),
	// ext IO
	.RTC(RTC),
	.ext_addr(cmos_addr),
	.ext_we(cmos_we),
	.ext_di(cmos_di),
	.ext_do(cmos_do)
);

assign rtc_adi = sys_via_pa_out;
assign rtc_as  = sys_via_pb_out[7];
assign rtc_ce  = sys_via_pb_out[6];
assign rtc_ds  = ic32[2];
assign rtc_r_nw  = ic32[1];

// Access Control Register (Master)
always @(posedge CLK48M_I) begin 

	if (!reset_n) begin
		{ acc_irr, acc_tst, acc_ifj, acc_itu, acc_y, acc_x, acc_e, acc_d } <= 0;
		vdu_op <= 0;
	end else if (cpu_clken) begin
    // Access Control Register 0xFE34
		if (acccon_enable & ~cpu_r_nw) { acc_irr, acc_tst, acc_ifj, acc_itu, acc_y, acc_x, acc_e, acc_d } <= cpu_do;
		// vdu op indicates the last opcode fetch in 0xC000-0xDFFF
		if (cpu_sync) begin
			if (cpu_a[15:13] == 3'b110)
				vdu_op <= 1;
			else
				vdu_op <= 0;
		end
	end
end

// Shadow RAM (Master): 0x3000-0x7fff
assign SHADOW_RAM = (cpu_a[15:12] == 4'h3 || cpu_a[15:14] == 2'b01) && (acc_x | (acc_e & vdu_op & ~cpu_sync));

// FDC (Master)
fdc1772 #(.IMG_TYPE(2), .INVERT_HEAD_RA(1'b1), .EXT_MOTOR(1'b1), .CLK_EN(16'd4000)) FDC1772 (

	.clkcpu         ( CLK48M_I         ),
	.clk8m_en       ( mhz4_clken       ),

	.cpu_sel        ( fdc_enable       ),
	.cpu_rw         ( cpu_r_nw         ),
	.cpu_addr       ( cpu_a[1:0]       ),
	.cpu_dout       ( fdc_do           ),
	.cpu_din        ( cpu_do           ),

	.irq            ( fdc_irq          ),
	.drq            ( fdc_drq          ),

	.img_mounted    ( img_mounted      ),
	.img_size       ( img_size         ),
	.img_wp         ( 0                ),
	.img_ds         ( img_ds           ),
	.sd_lba         ( sd_lba           ),
	.sd_rd          ( sd_rd            ),
	.sd_wr          ( sd_wr            ),
	.sd_ack         ( sd_ack           ),
	.sd_buff_addr   ( sd_buff_addr     ),
	.sd_dout        ( sd_dout          ),
	.sd_din         ( sd_din           ),
	.sd_dout_strobe ( sd_dout_strobe   ),

	.floppy_drive   ( floppy_drive     ),
	.floppy_motor   ( !floppy_motor    ),
//.floppy_inuse<->( floppy_inuse     ),
	.floppy_side    ( floppy_side      ),
//.floppy_density ( floppy_density   ),
	.floppy_reset   ( floppy_reset     )
);

// FDC Control Register (Master)
always @(posedge CLK48M_I) begin 

	if (!reset_n) begin
		floppy_drive <= 4'b1111;
		{ floppy_side, floppy_reset, floppy_density } <= 0;
	end else if (cpu_clken) begin
    // Access Control Register 0xFE34
		if (fdcon_enable & ~cpu_r_nw) begin
			floppy_drive <= { 3'b111, ~cpu_do[0] };
			floppy_reset <= cpu_do[2];
			floppy_side <= ~cpu_do[4];
			floppy_density <= cpu_do[5];
		end
	end
end

//  Address translation logic for calculation of display address
always @(crtc_ma or crtc_ra or disp_addr_offs)
   begin : process_3
   if (crtc_ma[12] === 1'b 0)
      begin

//  No adjustment
      process_3_aa = crtc_ma[11:8];   

//  Address adjusted according to screen mode to compensate for
//  wrap at 0x8000.
      end
   else
      begin
      case (disp_addr_offs)
      2'b 00:
         begin

//  Mode 3 - restart at 0x4000
         process_3_aa = crtc_ma[11:8] + 4'd8;
         end
      2'b 01:
         begin

//  Mode 6 - restart at 0x6000
         process_3_aa = crtc_ma[11:8] + 4'd12;
         end
      2'b 10:
         begin

//  Mode 0,1,2 - restart at 0x3000
         process_3_aa = crtc_ma[11:8] + 4'd6;
         end
      2'b 11:
         begin

//  Mode 4,5 - restart at 0x5800
         process_3_aa = crtc_ma[11:8] + 4'd11;
         end
      default:
         ;
      endcase
      end

      display_a = crtc_ma[13] ? 
        {process_3_aa[3], 4'b 1111, crtc_ma[9:0]} :       // TTX VDU
        {process_3_aa[3:0], crtc_ma[7:0], crtc_ra[2:0]};  // HI RES
   end

// SOUND 
assign AUDIO_L = {sound_ao, 8'b00000000};
assign AUDIO_R = {sound_ao, 8'b00000000};

//  VIDPROC
assign vidproc_invert_n = 1'b 1; 
assign vidproc_disen = crtc_de & ~crtc_ra[3]; 

//  SAA5050
assign ttxt_glr = ~HSYNC; 
assign ttxt_dew = VSYNC; 
assign ttxt_crs = ~crtc_ra[0]; 
assign ttxt_lose = crtc_de; 

//  IC32 latch
assign sound_enable_n = ic32[0]; 
assign speech_write_n = ic32[1]; 
assign speech_read_n = ic32[2]; 
assign keyb_enable_n = ic32[3]; 
assign disp_addr_offs = ic32[5:4]; 
assign caps_lock_led_n = ic32[6]; 
assign shift_lock_led_n = ic32[7]; 

//  CPU data bus mux and interrupts
wire himem_enable = rom_enable && (romsel[3] === 1'b0);

//  All regions normally de-selected
assign cpu_di = ram_enable ? MEM_DI : 
	himem_enable ? MEM_DI :
	rom_enable ? MEM_DI : 
	mos_enable ? MEM_DI :
	crtc_enable ? crtc_do : 
	acia_enable ? 8'b 00000010 : 
	sys_via_enable ? sys_via_do : 
	user_via_enable ? user_via_do : 
	adc_enable ? adc_do : 
	acccon_enable ? acccon :
	(romsel_enable & master) ? romsel :
	fdc_enable ? fdc_do :
	//tube_enable === 1'b 1 ? tube_do : 
	//adlc_enable === 1'b 1 ? bbcddr_out :
	8'd0;

//  un-decoded locations are pulled down by RP1
assign cpu_irq_n = ~sys_via_irq & ~user_via_irq & ~acc_irr; // & tube_irq_n;
assign cpu_nmi_n = ~fdc_irq & ~fdc_drq;

// can we write to ram? Further decodig happens on top-level to deal with sideways ram etc
assign ram_we = ~RESET_I & ~cpu_r_nw;

// system via interrupt lines.
assign sys_via_ca1_in = VSYNC;
assign sys_via_ca2_in = keyb_int; 
assign sys_via_cb1_in = 1'b1;
assign sys_via_cb2_in = crtc_lpstb;

assign sys_via_pa_in = (master & rtc_ce & rtc_ds & rtc_r_nw) ? rtc_do : { keyb_out, sys_via_pa_out[6:0] };
//assign sys_via_pa_in = { keyb_out, sys_via_pa_out[6:0] };

//  Sound
assign sound_di = sys_via_pa_out; 

//  Others (idle until missing bits implemented)
assign sys_via_pb_in[7:4] = { 2'b11, !joy_but[1], !joy_but[0] }; 
assign sys_via_pb_in[3:0] = sys_via_pb_out[3:0];

// Fixes Planetoid, Snapper etc
assign user_via_pa_in = user_via_pa_out; 
assign user_via_pb_in = user_via_pb_out;

assign MEM_ADR = cpu_phi0 ? cpu_a[15:0] : display_a;
assign MEM_WE = ram_we & cpu_phi0;
assign MEM_DO = cpu_do;

endmodule
