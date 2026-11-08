`timescale 1ns / 1ps

module frame_fetcher
#(
    parameter N_BURSTS = 38, 
    parameter BURST_LEN = 16, // max 16 (AXI3) 
    parameter TRANS_SIZE = 3'b010,
    parameter BURST_SIZE = BURST_LEN * (1 << TRANS_SIZE) //=64 
)
(
    input wire m_axi_aclk,m_axi_aresetn, //active low reset 
    input wire i_start, 
    input wire [31:0] i_base_addr, 
    output reg o_done, o_err,

    //AR channel (Manager)
    output reg[31:0]    m_axi_araddr, 
    output wire[3:0]    m_axi_arlen,
    output wire[2:0]    m_axi_arsize, 
    output wire[1:0]    m_axi_arburst,  
    output reg          m_axi_arvalid, 
    input wire          m_axi_arready,

    output wire [5:0] m_axi_arid,      
    output wire [1:0] m_axi_arlock, // 2 bits (AXI3)
    output wire [3:0] m_axi_arcache,
    output wire [2:0] m_axi_arprot,
    output wire [3:0] m_axi_arqos,    
     

    //R channel  
    input wire[31:0]    m_axi_rdata, 
    input wire[1:0]     m_axi_rresp, 
    input wire          m_axi_rlast, 
    input wire          m_axi_rvalid, 
    output reg          m_axi_rready, 

    //BRAM 
    output reg o_bram_wenb, 
    output reg[9:0] o_bram_addr,
    output reg[31:0] o_bram_din
);

reg  start_d;
wire start_pulse = i_start && !start_d;    // HIGH for 1 cycle on the rising edge

always @(posedge m_axi_aclk)
    begin
        if(!m_axi_aresetn) start_d <= 0;
        else         start_d <= i_start;
    end

//Initial AR channel setup 
assign m_axi_arid    = 0;
assign m_axi_arlock  = 2'b00;
assign m_axi_arcache = 4'h2;
assign m_axi_arprot  = 3'b000;
assign m_axi_arqos   = 4'h0;


//Address burst setting
assign m_axi_arlen = BURST_LEN - 1; 
assign m_axi_arsize = TRANS_SIZE; 
assign m_axi_arburst = 2'b01; 


//Burst counter and handshake setup 
wire ar_hs = (m_axi_arready && m_axi_arvalid); 
wire r_hs = (m_axi_rready && m_axi_rvalid);
reg[5:0] burst_cnter; 
wire last_burst = (burst_cnter == N_BURSTS - 1); 
wire burst_done = (r_hs && m_axi_rlast);

//
// AR channel 
//

//States
localparam AR_IDLE = 2'b00;
localparam AR_SEND = 2'b01; 
localparam AR_WAIT = 2'b10; 

reg [1:0] cur_ar_state, nxt_ar_state;

//Reg process 
always @(posedge m_axi_aclk)
    begin
        if(!m_axi_aresetn)
            begin
                cur_ar_state <= AR_IDLE; 
                m_axi_arvalid <= 0;
                o_done <= 0;
            end
        else 
            begin 
                cur_ar_state <= nxt_ar_state; 
                m_axi_arvalid <= (nxt_ar_state == AR_SEND);

                case(cur_ar_state)
                    AR_IDLE: 
                    if(start_pulse) begin 
                        burst_cnter <= 0; 
                        o_done <= 0;   
                        m_axi_araddr <= i_base_addr;
                    end 

                    AR_SEND:
                    if(ar_hs) begin
                        //move to next burst = size of burst * size of per transfer 
                        m_axi_araddr <= m_axi_araddr + BURST_SIZE;
                    end

                    AR_WAIT: 
                    if(burst_done) begin 
                        //increase burst counter; 
                        if(last_burst) o_done <= 1; 
                        else burst_cnter <= burst_cnter + 1;
                    end 

                endcase
            end 
    end

//State trans 
always @(*)
    begin 
        nxt_ar_state = cur_ar_state; 
        case(cur_ar_state)
            AR_IDLE: if(start_pulse) nxt_ar_state = AR_SEND;
            AR_SEND: if(ar_hs) nxt_ar_state = AR_WAIT;
            AR_WAIT: 
                begin
                    if(burst_done && !last_burst) nxt_ar_state = AR_SEND; 
                    else if(burst_done && last_burst) nxt_ar_state = AR_IDLE;
                end
            default: nxt_ar_state = AR_IDLE;
        endcase 

    end


//
//R channel 
//

reg [9:0] wr_ptr; 

localparam R_IDLE    = 1'b0; 
localparam R_RECEIVED = 1'b1;

reg nxt_r_state,cur_r_state;

//Reg process 
always @(posedge m_axi_aclk)
    begin
        if(!m_axi_aresetn)
            begin
                cur_r_state <= R_IDLE;
                m_axi_rready <= 0;
                o_err        <= 0;
                o_bram_wenb    <= 0;
            end
        else
            begin
                cur_r_state <= nxt_r_state;
                m_axi_rready <= (nxt_r_state == R_RECEIVED); 
                o_bram_wenb <= 0; //default = no write 
                if(start_pulse)
                    begin 
                        wr_ptr <= 0; 
                        o_err <= 0;
                    end
                if(r_hs) 
                    begin
                        //Write data into bram  
                        o_bram_wenb <= 1; 
                        o_bram_addr <= wr_ptr; 
                        o_bram_din <= m_axi_rdata;

                        //increase write addr
                        wr_ptr <= wr_ptr + 1; 
                        if(m_axi_rresp != 2'b00) o_err <= 1;
                    end
            end
    end

//State trans 
always @(*)
    begin
        nxt_r_state = cur_r_state;
        case(cur_r_state)
            R_IDLE: if(ar_hs) nxt_r_state = R_RECEIVED;   // TODO
            R_RECEIVED: if(r_hs && m_axi_rlast) nxt_r_state = R_IDLE;
            default:   nxt_r_state = R_IDLE;
        endcase
    end

endmodule