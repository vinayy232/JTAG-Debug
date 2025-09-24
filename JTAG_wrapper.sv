module JTAG_wrapper
 #(
    parameter REG1_SIZE = 2,
    parameter REG2_SIZE = 7,
    parameter REG3_SIZE = 32
 )
 (
  //  JTAG TAP PORTS

input logic tms_i,    // JTAG test mode select pad
input logic tck_i,      // JTAG test clock pad
input logic rst_ni,     // JTAG test reset pad
input logic  td_i,      // JTAG test data input pad
output logic td_o,      // JTAG test data output pad
//output  tdo_padoe_o;    // Output enable for JTAG test data output pad

// TAP states
output logic  shift_dr_o,
output logic  update_dr_o,
output logic  capture_dr_o,

// Select signals for boundary scan or mbist
output logic  memory_sel_o,
output logic  fifo_sel_o,
output logic  confreg_sel_o,
//output  clk_byp_sel_o;
//output  observ_sel_o;

// TDO signal that is connected to TDI of sub-modules.
output logic  scan_in_o,

// TDI signals from sub-modules
input logic   memory_out_i,      // from reg1 module
input logic   fifo_out_i,    // from reg2 module
input logic   confreg_out_i,     // from reg4 module
//input   clk_byp_out_i;
//input   observ_out_i;

// JTAG Register ports

 input logic                    clk_i,
// input logic                    rst_ni, // already synched
 input logic                    enable_i_1, // rising edge of tck
 input logic                    enable_i_2, 
 input logic                    enable_i_3, 
 input logic                    capture_dr_i,// capture&sel
 input logic                    shift_dr_i, // shift&sel
 input logic                    update_dr_i, // update&sel
 input logic [REG1_SIZE-1:0]  jtagreg_in_i_1,
 input logic [REG2_SIZE-1:0]  jtagreg_in_i_2,
 input logic [REG3_SIZE-1:0]  jtagreg_in_i_3,
 input logic                    mode_i,
 input logic                    scan_in_i,
 output logic                   scan_out_o_1,
 output logic                   scan_out_o_2,
 output logic                   scan_out_o_3,
 output logic [REG1_SIZE-1:0] jtagreg_out_o_1,
 output logic [REG2_SIZE-1:0] jtagreg_out_o_2,
 output logic [REG3_SIZE-1:0] jtagreg_out_o_3
 );

 //Instantiations

  tap_top u_tap (
    // jtag
    .tms_i(tms_i),
    .tck_i(tck_i),
    .rst_ni(rst_ni),
    .td_i(td_i),
    .td_o(td_o),
    // tap states
    .shift_dr_o(shift_dr_o),
    .update_dr_o(update_dr_o),
    .capture_dr_o(capture_dr_o),
    // select signals for boundary scan or mbist
    .memory_sel_o(memory_sel_o),
    .fifo_sel_o(fifo_sel_o),
    .confreg_sel_o(confreg_sel_o),
    // tdo signal connected to tdi of sub modules
    .scan_in_o(scan_in_o),
    // tdi signals from sub modules
    .memory_out_i(memory_out_i),
    .fifo_out_i(fifo_out_i),
    .confreg_out_i(confreg_out_i)
  );

  jtagreg #(
    .JTAGREGSIZE(REG1_SIZE),
    .SYNC(0)
  ) i_jtagreg1 (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .enable_i(enable_i_1),
    .capture_dr_i(capture_dr_i),
    .shift_dr_i(shift_dr_i),
    .update_dr_i(update_dr_i),
    .jtagreg_in_i(jtagreg_in_i_1),
    .mode_i(mode_i),
    .scan_in_i(scan_in_i),
    .scan_out_o(scan_out_o_1),
    .jtagreg_out_o(jtagreg_out_o_1)
  );

  jtagreg #(
    .JTAGREGSIZE(REG2_SIZE),
    .SYNC(0)
  ) i_jtagreg2 (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .enable_i(enable_i_2),
    .capture_dr_i(capture_dr_i),
    .shift_dr_i(shift_dr_i),
    .update_dr_i(update_dr_i),
    .jtagreg_in_i(jtagreg_in_i_2),
    .mode_i(mode_i),
    .scan_in_i(scan_in_i),
    .scan_out_o(scan_out_o_2),
    .jtagreg_out_o(jtagreg_out_o_2)
  );


 jtagreg #(
    .JTAGREGSIZE(REG3_SIZE),
    .SYNC(0)
  ) i_jtagreg3 (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .enable_i(enable_i_3),
    .capture_dr_i(capture_dr_i),
    .shift_dr_i(shift_dr_i),
    .update_dr_i(update_dr_i),
    .jtagreg_in_i(jtagreg_in_i_3),
    .mode_i(mode_i),
    .scan_in_i(scan_in_i),
    .scan_out_o(scan_out_o_3),
    .jtagreg_out_o(jtagreg_out_o_3)
  );

endmodule



