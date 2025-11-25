`timescale 1ns/1ps

module apb_downcounter #(
    parameter ADDR_WIDTH = 4,
    parameter DATA_WIDTH = 32
)(
    input  logic                  PCLK,
    input  logic                  PRESETn,
    input  logic                  PSEL,
    input  logic                  PENABLE,
    input  logic                  PWRITE,
    input  logic [ADDR_WIDTH-1:0] PADDR,
    input  logic [DATA_WIDTH-1:0] PWDATA,
    output logic [DATA_WIDTH-1:0] PRDATA,
    output logic                  PREADY,
    output logic                  PSLVERR
);

    localparam logic [ADDR_WIDTH-1:0] ADDR_CTRL = 'h0;
    localparam logic [ADDR_WIDTH-1:0] ADDR_MAX  = 'h4;
    localparam logic [ADDR_WIDTH-1:0] ADDR_CUR  = 'h8;

    logic [DATA_WIDTH-1:0] reg_ctrl;
    logic [DATA_WIDTH-1:0] reg_max;
    logic [DATA_WIDTH-1:0] reg_cur;
    logic [19:0] tick; // Увеличиваем размер счетчика для большей задержки

    assign PREADY  = 1'b1;
    assign PSLVERR = 1'b0;

    always_ff @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            reg_ctrl <= '0;
            reg_max  <= '0;
            reg_cur  <= '0;
            tick <= 0;
        end else begin
            if (PSEL && PENABLE && PWRITE) begin
                case (PADDR)
                    ADDR_CTRL: begin
                        reg_ctrl <= PWDATA;
                        if (PWDATA[1]) begin
                            reg_cur <= reg_max;
                        end
                    end
                    ADDR_MAX: reg_max <= PWDATA;
                    default: ;
                endcase
            end

            if (reg_ctrl[0]) begin
                tick <= tick + 1;
                if (tick == 20'd99999) begin   // МЕДЛЕННО - каждые 100000 тактов!
                    if (reg_cur > 0) 
                        reg_cur <= reg_cur - 1;
                    tick <= 0;
                end
            end else begin
                tick <= 0;
            end
        end
    end

    always_comb begin
        PRDATA = '0;
        if (PSEL && PENABLE && !PWRITE) begin
            case (PADDR)
                ADDR_CTRL: PRDATA = reg_ctrl;
                ADDR_MAX:  PRDATA = reg_max;
                ADDR_CUR:  PRDATA = reg_cur;
                default:   PRDATA = '0;
            endcase
        end
    end

endmodule