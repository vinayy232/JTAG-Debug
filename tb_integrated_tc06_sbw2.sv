module tb_integrated;

  timeunit 1ns;
  timeprecision 1ps;

  //parameters

  localparam int unsigned JTAG_PERIOD = 10;
  localparam int unsigned JTAG_IRLEN = 5;

  localparam int unsigned REG1_SIZE = 2;
  localparam int unsigned REG2_SIZE = 7;
  localparam int unsigned REG3_SIZE = 32;

  localparam IDCODE         = 5'b00010;
  localparam REG1           = 5'b00100;
  localparam REG2           = 5'b00101;
  localparam REG3           = 5'b00110;
  localparam REG4           = 5'b00111;
  localparam REG5           = 5'b01000;
  localparam REG6           = 5'b01001;
  localparam BYPASS         = 5'b11111;
  parameter int unsigned NrHarts = 1;
  parameter int unsigned BusWidth = 32;
  parameter logic [NrHarts-1:0] SelectableHarts = {NrHarts{1'b1}};
  parameter int unsigned        DmBaseAddress    = '0;
  parameter bit          ReadByteEnable = 1;


  logic clk_i;
  logic rst_ni;

  logic jtag_trst;
  logic jtag_tck;
  logic jtag_tms;
  logic jtag_tdi;

  logic jtag_tdo;

  logic s_tap_shiftdr;
  logic s_tap_updatedr;
  logic s_tap_capturedr;
  logic s_tap_reg1_sel;
  logic s_tap_reg2_sel;
  logic s_tap_reg3_sel;
  logic s_tap_tdo;
  logic s_tap_reg1_tdi;
  logic s_tap_reg2_tdi;
  logic s_tap_reg3_tdi;

  logic s_mode;

  logic [REG1_SIZE-1:0] s_reg1_in;
  logic [REG2_SIZE-1:0] s_reg2_in;
  logic [REG3_SIZE-1:0] s_reg3_in;

  logic [REG1_SIZE-1:0] s_reg1_out;
  logic [REG2_SIZE-1:0] s_reg2_out;
  logic [REG3_SIZE-1:0] s_reg3_out;

  //------dm_csrs ports------------------

  logic [31:0] next_dm_addr_i;
  logic testmode_i;
  logic dmi_rst_ni;
  logic [NrHarts-1:0] halted_i;
  logic [NrHarts-1:0] unavailable_i;
  logic [NrHarts-1:0] resumeack_i;
  dm::hartinfo_t [NrHarts-1:0] hartinfo_i; // Modify based on actual type
  logic [dm::DataCount-1:0][31:0] data_i;
  logic data_valid_i;
  logic cmderror_valid_i;
  dm::cmderr_e cmderror_i; // Modify based on actual type
  logic cmdbusy_i;
  logic ndmreset_ack_i;
  logic sbdata_valid_i;
  logic [BusWidth-1:0] sbaddress_i_csrs;
  logic [BusWidth-1:0] sbdata_i;
  logic sbbusy_i;
  logic sberror_valid_i;
  logic [2:0] sberror_i;
  
  logic dmi_req_ready_o;
  logic dmi_resp_valid_o;
  dm::dmi_resp_t dmi_resp_o; // Modify based on actual type
  logic ndmreset_o;
  logic dmactive_o;
  logic [19:0] hartsel_o;
  logic [NrHarts-1:0] haltreq_o;
  logic [NrHarts-1:0] resumereq_o;
  logic clear_resumeack_o;
  logic cmd_valid_o;
  dm::command_t cmd_o; // Modify based on actual type
  logic [dm::ProgBufSize-1:0][31:0] progbuf_o;
  logic [dm::DataCount-1:0][31:0] data_o;
  logic [BusWidth-1:0] sbaddress_o_csrs;
  logic sbaddress_write_valid_o;
  logic sbreadonaddr_o;
  logic sbautoincrement_o;
  logic [2:0] sbaccess_o;
  logic sbreadondata_o;
  logic [BusWidth-1:0] sbdata_o_csrs;
  logic sbdata_read_valid_o;
  logic sbdata_write_valid_o;
  

  //--------dm_mem ports----------------------

  logic [NrHarts-1:0]               debug_req_o;
  logic [NrHarts-1:0]               halted_o;   // hart acknowledge halt
  logic [NrHarts-1:0]               resuming_o;  // hart is resuming
  logic                             data_valid_o; // data out is valid
  logic                             cmderror_valid_o;
  dm::cmderr_e                      cmderror_o;
  logic                             cmdbusy_o;
 //SRAM interface
  logic                             req;
  logic                             we;
  logic [BusWidth-1:0]              addr;
  logic [BusWidth-1:0]              wdata;
  logic [BusWidth/8-1:0]            be;
  logic [BusWidth-1:0]              rdata;

  //-----------------dm_sba ports-------------------------------

  logic                   master_req_o;
  logic [BusWidth-1:0]    master_add_o;
  logic                   master_we_o;
  logic [BusWidth-1:0]    master_wdata_o;
  logic [BusWidth/8-1:0]  master_be_o;
  logic                   master_gnt_i;
  logic                   master_r_valid_i;
  logic                   master_r_err_i;
  logic                   master_r_other_err_i; // *other_err_i has priority over *err_i
  logic [BusWidth-1:0]    master_r_rdata_i;
  logic [BusWidth-1:0]    sbaddress_o_sba;

  logic [BusWidth-1:0]    sbdata_o_sba;
  logic                   sbdata_valid_o;
  // control signals
  logic                   sbbusy_o;
  logic                   sberror_valid_o; // bus error occurred
  logic [2:0]             sberror_o; // bus error occurred
 
 assign s_reg1_in = 2'b00;
  assign s_reg2_in = 'h01;
  assign s_reg3_in = 32'h1234ABCD;


  //Instantiations

  integrated_top #(
    .REG1_SIZE(REG1_SIZE),
    .REG2_SIZE(REG2_SIZE),
    .REG3_SIZE(REG3_SIZE),
    .NrHarts(NrHarts),
    .BusWidth(BusWidth),
    .SelectableHarts(SelectableHarts),
    .DmBaseAddress(DmBaseAddress),
    .ReadByteEnable(ReadByteEnable)
  ) dut_top (
    // jtag
    .tms_i(jtag_tms),
    .tck_i(jtag_tck),
    .rst_ni(~jtag_trst),
    .td_i(jtag_tdi),
    .td_o(jtag_tdo),
    // tap states
    .shift_dr_o(s_tap_shiftdr),
    .update_dr_o(s_tap_updatedr),
    .capture_dr_o(s_tap_capturedr),
    // select signals for boundary scan or mbist
    .memory_sel_o(s_tap_reg1_sel),
    .fifo_sel_o(s_tap_reg2_sel),
    .confreg_sel_o(s_tap_reg3_sel),
    // tdo signal connected to tdi of sub modules
    .scan_in_o(s_tap_tdo),
    // tdi signals from sub modulesdmi_resp_ready_i
    .memory_out_i(s_tap_reg1_tdi),
    .fifo_out_i(s_tap_reg2_tdi),
    .confreg_out_i(s_tap_reg3_tdi),
    // JTAG Register
    .clk_i(jtag_tck),
    .enable_i_1(s_tap_reg1_sel),
    .enable_i_2(s_tap_reg2_sel),
    .enable_i_3(s_tap_reg3_sel),
    .capture_dr_i(s_tap_capturedr),
    .shift_dr_i(s_tap_shiftdr),
    .update_dr_i(s_tap_updatedr),
    .jtagreg_in_i_1(s_reg1_in),
    .jtagreg_in_i_2(s_reg2_in),
    .jtagreg_in_i_3(s_reg3_in),
    .mode_i(s_mode),
    .scan_in_i(s_tap_tdo),
    .scan_out_o_1(s_tap_reg1_tdi),
    .scan_out_o_2(s_tap_reg2_tdi),
    .scan_out_o_3(s_tap_reg3_tdi),
    .jtagreg_out_o_1(s_reg1_out),
    .jtagreg_out_o_2(s_reg2_out),
    .jtagreg_out_o_3(s_reg3_out),
     // dm_csrs module
    .dm_clk_i(clk_i),
    .dm_rst_ni(rst_ni),
    .next_dm_addr_i(next_dm_addr_i),
    .testmode_i(testmode_i),
    .dmi_rst_ni(dmi_rst_ni),
    .dmi_req_ready_o(dmi_req_ready_o),
    .dmi_resp_valid_o(dmi_resp_valid_o),
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
    .req_i(req),
    .we_i(we),
    .addr_i(addr),
    .wdata_i(wdata),
    .be_i(be),
    .rdata_o(rdata),
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

  //Back Annotation after synthesis
  /*initial
  begin
    $sdf_annotate("../../workspace/synthesis/integrated_top_netlist.sdf",tb_integrated.dut_top,,"sdf.log","MAXIMUM");
  end
  */
  /*  //Back Annotation after pnr
  initial
  begin
    $sdf_annotate("../../workspace/physical_design/integrated_top.sdf",tb_integrated.dut_top,,"sdf.log","MAXIMUM");
  end
*/
  // improve time format
  initial begin: timing_format
    $timeformat(-9, 0, "ns", 9);
  end: timing_format

   // Clock generation
   always
    #5 clk_i = ~clk_i;


  // actual test sequence
  initial begin
       // Initialize inputs
     logic [127:0] dr_out;
    s_mode = 0;

    jtag_trst = 1'b0;
    jtag_tdi = 1'b0;
    jtag_tms = 1'b0;
    jtag_tck = 1'b0;

    rst_ni = 0;
    clk_i = 0;
    next_dm_addr_i = 32'h0;
    testmode_i = 0;
    dmi_rst_ni = 0;
    halted_i = {NrHarts{1'b0}};
    unavailable_i = {NrHarts{1'b0}};
    resumeack_i = {NrHarts{1'b0}};
    hartinfo_i = '0; // Modify based on actual initialization
    data_i = '0; // Modify based on actual initialization
    data_valid_i = 0;
    cmderror_valid_i = 0;
    cmderror_i = dm::CmdErrNone; // Modify based on actual initialization
    cmdbusy_i = 0;
    ndmreset_ack_i = 0;
    sbdata_valid_i = 0;
    sbdata_i = '0;
    sbbusy_i = 0;
    sberror_valid_i = 0;
    sberror_i = 3'b000;
    req = 0;
    we = 0;
    master_gnt_i = 0;
    master_r_valid_i = 0;
    master_r_err_i = 0;
    master_r_other_err_i = 0;

    #10 rst_ni = 1; // Release reset
    #10 dmi_rst_ni = 1;
 ///*   
//------------dm_control register write for settting dmactive signal high----------------------
    jtag_hard_rst();
   // jtag_rst();

    #100 s_mode = 1'b1;
    #100 s_mode = 1'b0;

    jtag_selectir(REG1);
    jtag_senddr(REG1_SIZE, 2'h2, dr_out);
    assert (dr_out === s_reg1_in)
      else
        $error("dr register of tap1 contains: %0h expected: %0h",
        dr_out, s_reg1_in);

    jtag_selectir(REG2);
    jtag_senddr(REG2_SIZE, 'h10, dr_out);
    assert (dr_out === s_reg2_in)
      else
        $error("dr register of tap2 contains: %0h expected: %0h",
        dr_out, s_reg2_in);


    jtag_selectir(REG3);
    jtag_senddr(REG3_SIZE, 'h1, dr_out);
    assert (dr_out === s_reg3_in)
      else
        $error("dr register of tap3 contains: %0h expected: %0h",
        dr_out, s_reg3_in);


    #100 s_mode = 1'b1;
    dm_control_write_test();
    #100 s_mode = 1'b0;
    /*
  //---------------------Writing to Debug Module Control & Status Register Data0 located at address 8'h04 --------------------------------------------------------------
    jtag_hard_rst();
   // jtag_rst();

    #100 s_mode = 1'b1;
    #100 s_mode = 1'b0;

    jtag_selectir(REG1);
    jtag_senddr(REG1_SIZE, 2'h2, dr_out);
    assert (dr_out === s_reg1_in)
      else
        $error("dr register of tap1 contains: %0h expected: %0h",
        dr_out, s_reg1_in);

    jtag_selectir(REG2);
    jtag_senddr(REG2_SIZE, 'h04, dr_out);
    assert (dr_out === s_reg2_in)
      else
        $error("dr register of tap2 contains: %0h expected: %0h",
        dr_out, s_reg2_in);


    jtag_selectir(REG3);
    jtag_senddr(REG3_SIZE, 'h12345678, dr_out);
    assert (dr_out === s_reg3_in)
      else
        $error("dr register of tap3 contains: %0h expected: %0h",
        dr_out, s_reg3_in);


    #100 s_mode = 1'b1;
    dtm_write_1();
    #100 s_mode = 1'b0;
/*    
//--------------------Reading from data0 register-------------------------------------------
  jtag_hard_rst();
   // jtag_rst();

    #100 s_mode = 1'b1;
    #100 s_mode = 1'b0;

    jtag_selectir(REG1);
    jtag_senddr(REG1_SIZE, 2'h1, dr_out);
    assert (dr_out === s_reg1_in)
      else
        $error("dr register of tap1 contains: %0h expected: %0h",
        dr_out, s_reg1_in);

    jtag_selectir(REG2);
    jtag_senddr(REG2_SIZE, 'h04, dr_out);
    assert (dr_out === s_reg2_in)
      else
        $error("dr register of tap2 contains: %0h expected: %0h",
        dr_out, s_reg2_in);

    #100 s_mode = 1'b1;
    dtm_read(); 
    #100 s_mode = 1'b0; 
    
    */   
    //--------------dm_mem module SRAM interface read & write--------------------------------
   //sram_op();
    //--------------------Write operation through System Bus Access--------------------------------------------------
    
     //-----------------step 1: Configuring the SBCS register for setting sbacess to 3'b010 i.e 32 bit access,sbreadonaddr bit to 1(required for misalignment error test case) & sbautoincrement to 1(required if we want to auto increment sbaddress after sba operation)-------------
///*
  jtag_hard_rst();
   // jtag_rst();

    #100 s_mode = 1'b1;
    #100 s_mode = 1'b0;

    jtag_selectir(REG1);
    jtag_senddr(REG1_SIZE, 2'h2, dr_out);
    assert (dr_out === s_reg1_in)
      else
        $error("dr register of tap1 contains: %0h expected: %0h",
        dr_out, s_reg1_in);

    jtag_selectir(REG2);
    jtag_senddr(REG2_SIZE, 'h38, dr_out);
    assert (dr_out === s_reg2_in)
      else
        $error("dr register of tap2 contains: %0h expected: %0h",
        dr_out, s_reg2_in);


    jtag_selectir(REG3);
    jtag_senddr(REG3_SIZE, 'h00150000, dr_out); 
    assert (dr_out === s_reg3_in)
      else
        $error("dr register of tap3 contains: %0h expected: %0h",
        dr_out, s_reg3_in);


    #100 s_mode = 1'b1;
    #100 s_mode = 1'b0;
  // */ 
 ///*   
 //   ------------------step2 : Writing to sbaddress0 register of dm_csrs-------------------
   jtag_hard_rst();
  //  jtag_rst();

    #100 s_mode = 1'b1;
    #100 s_mode = 1'b0;

    jtag_selectir(REG1);
    jtag_senddr(REG1_SIZE, 2'h2, dr_out);
    assert (dr_out === s_reg1_in)
      else
        $error("dr register of tap1 contains: %0h expected: %0h",
        dr_out, s_reg1_in);

    jtag_selectir(REG2);
    jtag_senddr(REG2_SIZE, 'h39, dr_out);
    assert (dr_out === s_reg2_in)
      else
        $error("dr register of tap2 contains: %0h expected: %0h",
        dr_out, s_reg2_in);


    jtag_selectir(REG3);
    jtag_senddr(REG3_SIZE, 'h2000, dr_out); //Random address used only for testing purpose as the module is not integrated to the system bus
    assert (dr_out === s_reg3_in)
      else
        $error("dr register of tap3 contains: %0h expected: %0h",
        dr_out, s_reg3_in);


    #100 s_mode = 1'b1;
    // sba_op_2();
    #100 s_mode = 1'b0;

    //-------------------------step 3 : Writing the new data to be written at sbaddress to sbdata0 register------------
   ///*
   jtag_hard_rst();
    //jtag_rst();

   #100 s_mode = 1'b1;
   #100 s_mode = 1'b0;

    jtag_selectir(REG1);
    jtag_senddr(REG1_SIZE, 2'h2, dr_out);
    assert (dr_out === s_reg1_in)
      else
        $error("dr register of tap1 contains: %0h expected: %0h",
        dr_out, s_reg1_in);

    jtag_selectir(REG2);
    jtag_senddr(REG2_SIZE, 'h3C, dr_out);
    assert (dr_out === s_reg2_in)
      else
        $error("dr register of tap2 contains: %0h expected: %0h",
        dr_out, s_reg2_in);


    jtag_selectir(REG3);
    jtag_senddr(REG3_SIZE, 'h5A5A5A5A, dr_out); 
    assert (dr_out === s_reg3_in)
      else
        $error("dr register of tap3 contains: %0h expected: %0h",
        dr_out, s_reg3_in);


   #100 s_mode = 1'b1;
    sba_op_1(); 
    #100 s_mode = 1'b0;
	//*/
      
     $stop();
  end

  // jtag & dm_csrs commands
  task jtag_rst;
    integer halfperiod;
    begin
      if ($test$plusargs("debug"))
        $display("%t: rst start", $time);
      halfperiod = JTAG_PERIOD / 2;
      jtag_tck = 1'b0;
      jtag_tms = 1'b0;
      jtag_tck = #halfperiod 1'b1;
      jtag_tck = #halfperiod 1'b0;
      jtag_tms = 1'b1;
      jtag_tck = #halfperiod 1'b1;
      jtag_tck = #halfperiod 1'b0;
      jtag_tms = 1'b1;
      jtag_tck = #halfperiod 1'b1;
      jtag_tck = #halfperiod 1'b0;
      jtag_tms = 1'b1;
      jtag_tck = #halfperiod 1'b1;
      jtag_tck = #halfperiod 1'b0;
      jtag_tms = 1'b1;
      jtag_tck = #halfperiod 1'b1;
      jtag_tck = #halfperiod 1'b0;
      jtag_tms = 1'b0;
      jtag_tck = #halfperiod 1'b1;
      jtag_tck = #halfperiod 1'b0;
      jtag_tms = 1'b0;
      jtag_tck = #halfperiod 1'b1;
      jtag_tck = #halfperiod 1'b0;
      jtag_tms = 1'b0;
      jtag_tck = #halfperiod 1'b0;
      if ($test$plusargs("debug"))
        $display("%t: rst done", $time);
    end
  endtask

  task jtag_hard_rst;
    integer halfperiod;
    begin
      if ($test$plusargs("debug"))
        $display("%t: hard rst start", $time);

      halfperiod = JTAG_PERIOD / 2;
      jtag_tck  = 1'b0;
      jtag_trst = 1'b0;
      jtag_tck = #halfperiod 1'b1;
      jtag_tck = #halfperiod 1'b0;
      jtag_trst = 1'b1;
      jtag_tck = #halfperiod 1'b1;
      jtag_tck = #halfperiod 1'b0;
      jtag_trst = 1'b1;
      jtag_tck = #halfperiod 1'b1;
      jtag_tck = #halfperiod 1'b0;
      jtag_trst = 1'b1;
      jtag_tck = #halfperiod 1'b1;
      jtag_tck = #halfperiod 1'b0;
      jtag_trst = 1'b1;
      jtag_tck = #halfperiod 1'b1;
      jtag_tck = #halfperiod 1'b0;
      jtag_trst = 1'b0;
      jtag_tck = #halfperiod 1'b1;
      jtag_tck = #halfperiod 1'b0;
      jtag_trst = 1'b0;
      jtag_tck = #halfperiod 1'b1;
      jtag_tck = #halfperiod 1'b0;
      jtag_trst = 1'b0;
      jtag_tck = #halfperiod 1'b0;
      if ($test$plusargs("debug"))
        $display("%t: hard rst end", $time);

    end
  endtask

  task jtag_selectir (
    input [JTAG_IRLEN-1:0] instruction
  );
    integer                 halfperiod;
    integer                 i;
    begin
      if ($test$plusargs("debug"))
        $display("%t: select ir start, ir=0x%0h", $time, instruction);

      halfperiod = JTAG_PERIOD / 2;
      jtag_tck  = 1'b0; // TODO: buggy?
      jtag_tck = #halfperiod 1'b1;
      jtag_tck = #halfperiod 1'b0;
      jtag_tms = 1'b1;             //selectDR
      jtag_tck = #halfperiod 1'b1;
      jtag_tck = #halfperiod 1'b0;
      jtag_tms = 1'b1;             //selectIR
      jtag_tck = #halfperiod 1'b1;
      jtag_tck = #halfperiod 1'b0;
      jtag_tms = 1'b0;             //captureIR
      jtag_tck = #halfperiod 1'b1;
      jtag_tck = #halfperiod 1'b0;
      jtag_tms = 1'b0;             //shiftIR
      if ($test$plusargs("debug"))
        $display("%t: select ir capture start", $time);
      for (i=0 ; i < JTAG_IRLEN ; i=i+1)
        begin
          jtag_tck = #halfperiod 1'b1;
          jtag_tck = #halfperiod 1'b0;
          if (i == (JTAG_IRLEN - 1) )
            jtag_tms = 1'b1;             //exit1IR
          else
            jtag_tms = 1'b0;             //shiftIR
          jtag_tdi = instruction[i];
        end
      if ($test$plusargs("debug"))
        $display("%t: select ir capture end", $time);
      jtag_tck = #halfperiod 1'b1;
      jtag_tck = #halfperiod 1'b0;
      jtag_tms = 1'b0;             //pauseIR
      jtag_tdi = 1'b0;
      jtag_tck = #halfperiod 1'b1;
      jtag_tck = #halfperiod 1'b0;
      jtag_tms = 1'b1;             //exit2IR
      jtag_tck = #halfperiod 1'b1;
      jtag_tck = #halfperiod 1'b0;
      jtag_tms = 1'b1;             //updateIR
      jtag_tck = #halfperiod 1'b1;
      jtag_tck = #halfperiod 1'b0;
      jtag_tms = 1'b0;             //run-test-idle
      jtag_tck = #halfperiod 1'b1;
      jtag_tck = #halfperiod 1'b0;
      jtag_tms = 1'b0;             //run-test-idle
      jtag_tck = #halfperiod 1'b1;
      jtag_tck = #halfperiod 1'b0;
      jtag_tms = 1'b0;             //run-test-idle

      jtag_tck = #halfperiod 1'b0;
      if ($test$plusargs("debug"))
        $display("%t: select ir end", $time);

    end
  endtask

  task jtag_senddr (
    input integer number,
    input [127:0] data,
    output [127:0] dr_out
  );
    integer       halfperiod;
    integer       i;
    logic [127:0] data_out;
    begin
      if ($test$plusargs("debug"))
        $display("%t: select dr start, dr=0x%0h", $time, data);

      data_out = 0;
      halfperiod = JTAG_PERIOD / 2;
      jtag_tck  = 1'b0;
      jtag_tck = #halfperiod 1'b1;
      jtag_tck = #halfperiod 1'b0;
      jtag_tms = 1'b1;             //selectDR
      jtag_tck = #halfperiod 1'b1;
      jtag_tck = #halfperiod 1'b0;
      jtag_tms = 1'b0;             //captureDR
      jtag_tck = #halfperiod 1'b1;
      jtag_tck = #halfperiod 1'b0;
      jtag_tms = 1'b0;             //shiftNR
      for (i=0 ; i < number ; i=i+1)
        begin
          jtag_tck = #halfperiod 1'b1;
          if (i > 0)
            data_out[i-1] = jtag_tdo;
          jtag_tck = #halfperiod 1'b0;
          if (i == (number - 1) )
            jtag_tms = 1'b1;             //exit1DR
          else
            jtag_tms = 1'b0;             //shiftDR
          jtag_tdi = data[i];
        end
      jtag_tck = #halfperiod 1'b1;
      data_out[number-1] = jtag_tdo;
      jtag_tck = #halfperiod 1'b0;
      jtag_tms = 1'b0;             //pauseDR
      jtag_tdi = 1'b0;
      jtag_tck = #halfperiod 1'b1;
      jtag_tck = #halfperiod 1'b0;
      jtag_tms = 1'b1;             //exit2DR
      jtag_tck = #halfperiod 1'b1;
      jtag_tck = #halfperiod 1'b0;
      jtag_tms = 1'b1;             //updateDR
      jtag_tck = #halfperiod 1'b1;
      jtag_tck = #halfperiod 1'b0;
      jtag_tms = 1'b0;             //run-test-idle
      jtag_tck = #halfperiod 1'b1;
      jtag_tck = #halfperiod 1'b0;
      jtag_tms = 1'b0;             //run-test-idle
      jtag_tck = #halfperiod 1'b1;
      jtag_tck = #halfperiod 1'b0;
      jtag_tms = 1'b0;             //run-test-idle

      jtag_tck = #halfperiod 1'b0;
      dr_out = data_out;
      if ($test$plusargs("debug"))
        $display("%t: data captured from register: 0x%0h", $time, data_out);
    end

  endtask

task dm_control_write_test;
  begin
  @(posedge clk_i);
  $display("Starting DM Control Write Test Case");
  wait(dmi_req_ready_o);
  @(posedge clk_i);

  wait(dmi_resp_valid_o == 1);

  // Check if the data has been correctly written to the data registers
  if (dmactive_o == 1) begin
    $display("DM Control Write Test Passed!");
  end else begin
    $display("DM Control Write Test Failed!");
  end
  end
endtask

task dtm_write_1;
begin
  @(posedge clk_i);
  $display("Starting DTM Write Test Case");
  wait(dmi_req_ready_o);              // Wait for request to be ready
  @(posedge clk_i);
  wait(data_o[0][31:0]);       // Wait until the data is written
  // Check if the data has been correctly written to the data register
  if (data_o[0][31:0] == 32'h12345678) begin
    $display("DTM Write Test Passed!");
  end else begin
    $display("DTM Write Test Failed: Expected 0x12345678, got 0x%h",data_o[0][31:0]);
  end
end
endtask

task dtm_read;
begin
  @(posedge clk_i);
  $display("Starting DTM Read Test Case");
  wait(dmi_req_ready_o);
  @(posedge clk_i);
  wait(dmi_resp_o.data);
  // Check if the response contains the correct data
  if (dmi_resp_o.data == 32'h12345678) begin
    $display("DTM Read Test Passed!");
    end 
  else begin
      $display("DTM Read Test Failed: Expected 0x12345678, got 0x%h", dmi_resp_o.data);
    end
end
endtask

task sram_op;
begin
   req = 1'b1;
   we = 1'b1;
   addr = 32'h00000380 ;   // Example address
   wdata = 32'hdeadbeef;
   
   be = 4'b1111;    // Enable all bytes
   wait(data_o[0][31:0]);
   assert(data_o[0][31:0]==32'hDEADBEEF) else $display("SRAM write failed");
   @(posedge clk_i);
    req = 1'b0;
    we = 1'b0;
    @(posedge clk_i);
    req = 1'b1;
    we = 1'b0;       // Read operation
    data_i[0] = 32'hDEADBEEF;
    data_i[1] = 32'b0;
    addr = 32'h00000380;   // Same address
    
    @( posedge clk_i);
    @(posedge clk_i);
    assert(rdata == 32'hDEADBEEF) else $display("SRAM read failed");

end
endtask

task sba_op_1;
begin
$display("Test Case: Starting SBA write operation");
  @(posedge clk_i);
  wait(dmi_req_ready_o);              // Wait for request to be ready
  repeat(2) @(posedge clk_i);
  master_gnt_i = 1; // Grant signal
  repeat(2) @(posedge clk_i); // Wait for operation
  master_r_valid_i = 1; // Valid read data
  @(posedge clk_i);
  master_r_valid_i = 0;
  master_gnt_i = 0;
  if (master_wdata_o == 32'h5A5A5A5A)
      $display("Write Operation Successful. Data written: %h", master_wdata_o);
  else
      $display("Write Operation Failed. Data written: %h", master_wdata_o);
end
endtask

task sba_op_2;
begin
  $display("Test Case: Starting SBA operation with address auto-increment feature");
  @(posedge clk_i);
  wait(dmi_req_ready_o);              // Wait for request to be ready
  repeat(2) @(posedge clk_i);
  master_gnt_i = 1; // Grant signal
  repeat(2) @(posedge clk_i); // Wait for operation
  master_r_valid_i = 1; // Valid read data
  @(posedge clk_i);
  master_r_valid_i = 0;
  master_gnt_i = 0;
  if (sbaddress_o_sba == 32'h2004)
      $display("Address Auto-increment Successful. New address: %h", sbaddress_o_sba);
    else
      $display("Address Auto-increment Failed. New address: %h", sbaddress_o_sba);
  
end
endtask
endmodule
