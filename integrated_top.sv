//`include "dm_pkg.sv"
import dm::*;
 module integrated_top
 #(
    parameter REG1_SIZE = 2,
    parameter REG2_SIZE = 7,
    parameter REG3_SIZE = 32,
    parameter int unsigned NrHarts = 1,
    parameter int unsigned BusWidth = 32,
    parameter logic [NrHarts-1:0] SelectableHarts = {NrHarts{1'b1}},
    parameter int unsigned        DmBaseAddress    = '0,
    parameter bit          ReadByteEnable = 1

 )
 (
  input  logic                              dm_clk_i,           // Clock
  input  logic                              dm_rst_ni,          // Asynchronous reset active low
  input  logic [31:0]                       next_dm_addr_i,  // Static next_dm word address.
  input  logic                              testmode_i,
  input  logic                              dmi_rst_ni,      // sync. DTM reset,
                                                             // active-low
  //input  logic                              dmi_req_valid_i,
  output logic                              dmi_req_ready_o,
 // input  dm::dmi_req_t                      dmi_req_i,
  // every request needs a response one cycle later
  output logic                              dmi_resp_valid_o,
  //input  logic                              dmi_resp_ready_i,
  output dm::dmi_resp_t                     dmi_resp_o,
  // global ctrl
  output logic                              ndmreset_o,      // non-debug module reset active-high
  input  logic                              ndmreset_ack_i,  // non-debug module reset ack pulse
  output logic                              dmactive_o,      // 1 -> debug-module is active,
                                                             // 0 -> synchronous re-set
  // hart status
  input  dm::hartinfo_t [NrHarts-1:0]       hartinfo_i,      // static hartinfo
  input  logic [NrHarts-1:0]                halted_i,        // hart is halted
  input  logic [NrHarts-1:0]                unavailable_i,   // e.g.: powered down
  input  logic [NrHarts-1:0]                resumeack_i,     // hart acknowledged resume request
  // hart control
  output logic [19:0]                       hartsel_o,       // hartselect to ctrl module
  output logic [NrHarts-1:0]                haltreq_o,       // request to halt a hart
  output logic [NrHarts-1:0]                resumereq_o,     // request hart to resume
  output logic                              clear_resumeack_o,

  output logic                              cmd_valid_o,       // debugger writing to cmd field
  output dm::command_t                      cmd_o,             // abstract command
  input  logic                              cmderror_valid_i,  // an error occurred
  input  dm::cmderr_e                       cmderror_i,        // this error occurred
  input  logic                              cmdbusy_i,         // cmd is currently busy executing

  output logic [dm::ProgBufSize-1:0][31:0]  progbuf_o, // to system bus
  output logic [dm::DataCount-1:0][31:0]    data_o,

  input  logic [dm::DataCount-1:0][31:0]    data_i,
  input  logic                              data_valid_i,
  // system bus access module (SBA)
  output logic [BusWidth-1:0]               sbaddress_o_csrs,
  input  logic [BusWidth-1:0]               sbaddress_i_csrs,
  output logic                              sbaddress_write_valid_o,
  // control signals in
  output logic                              sbreadonaddr_o,
  output logic                              sbautoincrement_o,
  output logic [2:0]                        sbaccess_o,
  // data out
  output logic                              sbreadondata_o,
  output logic [BusWidth-1:0]               sbdata_o_csrs,
  output logic                              sbdata_read_valid_o,
  output logic                              sbdata_write_valid_o,
  // read data in
  input  logic [BusWidth-1:0]               sbdata_i,
  input  logic                              sbdata_valid_i,
  // control signals
  input  logic                              sbbusy_i,
  input  logic                              sberror_valid_i, // bus error occurred
  input  logic [2:0]                        sberror_i, 
  

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
 output logic [REG3_SIZE-1:0] jtagreg_out_o_3,

 // Debug memory ports

 output logic [NrHarts-1:0]               debug_req_o,
 output logic [NrHarts-1:0]               halted_o,    // hart acknowledge halt
 output logic [NrHarts-1:0]               resuming_o,  // hart is resuming
 output logic                             data_valid_o, // data out is valid
 output logic                             cmderror_valid_o,
 output dm::cmderr_e                      cmderror_o,
 output logic                             cmdbusy_o,
 //SRAM interface
 input  logic                             req_i,
 input  logic                             we_i,
 input  logic [BusWidth-1:0]              addr_i,
 input  logic [BusWidth-1:0]              wdata_i,
 input  logic [BusWidth/8-1:0]            be_i,
 output logic [BusWidth-1:0]              rdata_o,

// Dm_sba module ports

 output logic                   master_req_o,
 output logic [BusWidth-1:0]    master_add_o,
 output logic                   master_we_o,
 output logic [BusWidth-1:0]    master_wdata_o,
 output logic [BusWidth/8-1:0]  master_be_o,
 input  logic                   master_gnt_i,
 input  logic                   master_r_valid_i,
 input  logic                   master_r_err_i,
 input  logic                   master_r_other_err_i, // *other_err_i has priority over *err_i
 input  logic [BusWidth-1:0]    master_r_rdata_i,
 output logic [BusWidth-1:0]    sbaddress_o_sba,

 output logic [BusWidth-1:0]    sbdata_o_sba,
 output logic                   sbdata_valid_o,
  // control signals
 output logic                   sbbusy_o,
 output logic                   sberror_valid_o, // bus error occurred
 output logic [2:0]             sberror_o // bus error occurred

);
//Internal assignments
dm::dmi_req_t                      dmi_req_i;
logic                              dmi_req_valid_i;
logic                              dmi_resp_ready_i;

//----------The data values received in JTAG register ports are assigned to  corresponding ports of dmi_req_i variable----------------------
assign dmi_req_i.op =  dm::dtm_op_e'(jtagreg_out_o_1);
assign dmi_req_i.addr = jtagreg_out_o_2;
assign dmi_req_i.data = jtagreg_out_o_3;
//---If read/write operation request is received, then the following signals are set to initiate the operation------------------
assign dmi_req_valid_i  = (dmi_req_i.op != dm::DTM_NOP);
assign dmi_resp_ready_i = (dmi_req_i.op != dm::DTM_NOP);

//Instantiations

  JTAG_wrapper #(
    .REG1_SIZE(REG1_SIZE),
    .REG2_SIZE(REG2_SIZE),
    .REG3_SIZE(REG3_SIZE)
  ) dut_jtag (
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
    .confreg_out_i(confreg_out_i),
    // JTAG Register
    .clk_i(clk_i),
    .enable_i_1(enable_i_1),
    .enable_i_2(enable_i_2),
    .enable_i_3(enable_i_3),
    .capture_dr_i(capture_dr_i),
    .shift_dr_i(shift_dr_i),
    .update_dr_i(update_dr_i),
    .jtagreg_in_i_1(jtagreg_in_i_1),
    .jtagreg_in_i_2(jtagreg_in_i_2),
    .jtagreg_in_i_3(jtagreg_in_i_3),
    .mode_i(mode_i),
    .scan_in_i(scan_in_i),
    .scan_out_o_1(scan_out_o_1),
    .scan_out_o_2(scan_out_o_2),
    .scan_out_o_3(scan_out_o_3),
    .jtagreg_out_o_1(jtagreg_out_o_1),
    .jtagreg_out_o_2(jtagreg_out_o_2),
    .jtagreg_out_o_3(jtagreg_out_o_3)
  );

  Dbg_Module_wrapper #(
    .NrHarts(NrHarts),
    .BusWidth(BusWidth),
    .SelectableHarts(SelectableHarts),
    .DmBaseAddress(DmBaseAddress),
    .ReadByteEnable(ReadByteEnable)
  ) dut_dbg_module (
    // dm_csrs module
    .dm_clk_i(dm_clk_i),
    .dm_rst_ni(dm_rst_ni),
    .next_dm_addr_i(next_dm_addr_i),
    .testmode_i(testmode_i),
    .dmi_rst_ni(dmi_rst_ni),
    .dmi_req_valid_i(dmi_req_valid_i),
    .dmi_req_ready_o(dmi_req_ready_o),
    .dmi_req_i(dmi_req_i),  // Use the declared dmi_req_i
    .dmi_resp_valid_o(dmi_resp_valid_o),
    .dmi_resp_ready_i(dmi_resp_ready_i),
    .dmi_resp_o(dmi_resp_o),
    .ndmreset_o(ndmreset_o),
    .ndmreset_ack_i(ndmreset_ack_i),
    .dmactive_o(dmactive_o),
    .hartinfo_i(hartinfo_i),
    .halted_i(halted_i),
    .unavailable_i(unavailable_i),
    .resumeack_i(resumeack_i),
    .hartsel_o(hartsel_o),
    .haltreq_o(haltreq_o),
    .resumereq_o(resumereq_o),
    .clear_resumeack_o(clear_resumeack_o),
    .cmd_valid_o(cmd_valid_o),
    .cmd_o(cmd_o),          // Modify based on actual type
    .cmderror_valid_i(cmderror_valid_i),
    .cmderror_i(cmderror_i), // Modify based on actual type
    .cmdbusy_i(cmdbusy_i),
    .progbuf_o(progbuf_o),
    .data_o(data_o),
    .data_i(data_i),
    .data_valid_i(data_valid_i),
    .sbaddress_o_csrs(sbaddress_o_csrs),
    .sbaddress_i_csrs(sbaddress_i_csrs),
    .sbaddress_write_valid_o(sbaddress_write_valid_o),
    .sbbusy_i(sbbusy_i),
    .sberror_valid_i(sberror_valid_i),
    .sberror_i(sberror_i),
    .sbreadonaddr_o(sbreadonaddr_o),
    .sbautoincrement_o(sbautoincrement_o),
    .sbaccess_o(sbaccess_o),
    .sbreadondata_o(sbreadondata_o),
    .sbdata_o_csrs(sbdata_o_csrs),
    .sbdata_read_valid_o(sbdata_read_valid_o),
    .sbdata_write_valid_o(sbdata_write_valid_o),
    .sbdata_i(sbdata_i),
    .sbdata_valid_i(sbdata_valid_i),
    // dm_mem module
    .debug_req_o(debug_req_o),
    .halted_o(halted_o),
    .resuming_o(resuming_o),
    .data_valid_o(data_valid_o),
    .cmderror_valid_o(cmderror_valid_o),
    .cmderror_o(cmderror_o),
    .cmdbusy_o(cmdbusy_o),
    .req_i(req_i),
    .we_i(we_i),
    .addr_i(addr_i),
    .wdata_i(wdata_i),
    .be_i(be_i),
    .rdata_o(rdata_o),
    // dm_sba module
    .master_req_o(master_req_o),
    .master_add_o(master_add_o),
    .master_we_o(master_we_o),
    .master_wdata_o(master_wdata_o),
    .master_be_o(master_be_o),
    .master_gnt_i(master_gnt_i),
    .master_r_valid_i(master_r_valid_i),
    .master_r_err_i(master_r_err_i),
    .master_r_other_err_i(master_r_other_err_i),
    .master_r_rdata_i(master_r_rdata_i),
    .sbaddress_o_sba(sbaddress_o_sba),
    .sbdata_o_sba(sbdata_o_sba),
    .sbdata_valid_o(sbdata_valid_o),
    .sbbusy_o(sbbusy_o),
    .sberror_valid_o(sberror_valid_o),
    .sberror_o(sberror_o)
  );

 endmodule
