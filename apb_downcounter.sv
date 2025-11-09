module apb_downcounter #(
    parameter ADDR_WIDTH = 4,   // ширина адреса (можно хранить до 16 адресов)
    parameter DATA_WIDTH = 32   // ширина данных в битах
)(
    input  logic                  PCLK,      // тактовый сигнал
    input  logic                  PRESETn,   // сброс (активный низкий)
    input  logic                  PSEL,      // выбор устройства
    input  logic                  PENABLE,   // сигнал активности
    input  logic                  PWRITE,    // 1 = запись, 0 = чтение
    input  logic [ADDR_WIDTH-1:0] PADDR,     // адрес регистра
    input  logic [DATA_WIDTH-1:0] PWDATA,    // данные для записи

    output logic [DATA_WIDTH-1:0] PRDATA,    // данные для чтения
    output logic                  PREADY,    // готовность 
    output logic                  PSLVERR    // флаг ошибки
);

    //локальные константы - адреса регистров
    localparam logic [ADDR_WIDTH-1:0] ADDR_CTRL = 'h0;
    localparam logic [ADDR_WIDTH-1:0] ADDR_MAX  = 'h4;
    localparam logic [ADDR_WIDTH-1:0] ADDR_CUR  = 'h8;

    // Внутренние регистры - хранят данные
    logic [DATA_WIDTH-1:0] reg_ctrl;   // RW 0x00 - CTRL : управляющий регистр (бит0=ENABLE, бит1=LOAD)
    logic [DATA_WIDTH-1:0] reg_max;    // RW 0x04 - MAX  : максимальное значение счётчика
    logic [DATA_WIDTH-1:0] reg_cur;    // RO 0x08 - CUR  : текущее значение счётчика

    logic [3:0] tick; // внутренний счётчик тактов (будет считать такты PCLK, чтобы CUR уменьшался не каждый такт)

    assign PREADY  = 1'b1;  // устройство всегда готово
    assign PSLVERR = 1'b0;  // ошибок нет

    // Основная логика
    always_ff @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin // Сброс всех регистров
            reg_ctrl <= '0;
            reg_max  <= '0;
            reg_cur  <= '0;
        end else begin
            if (PSEL && PENABLE && PWRITE) begin    // Запись данных (apb write)
                case (PADDR)
                    ADDR_CTRL: begin
                        reg_ctrl <= PWDATA;
                        if (PWDATA[1]) begin    // Если бит LOAD = 1, загрузим MAX
                            reg_cur <= reg_max;
                        end
                    end
                    ADDR_MAX: begin
                        reg_max <= PWDATA;
                    end
                    default: ;
                endcase
            end

            // обратный счёт
            if (reg_ctrl[0] && !reg_ctrl[1]) begin  // Если ENABLE = 1 и LOAD = 0 — уменьшаем счётчик
                tick <= tick + 1;
                if (tick == 4'd9) begin   // уменьшаем CUR каждые 11 тактов
                    if (reg_cur != 0) reg_cur <= reg_cur - 1;
                        tick <= 0;
                    end
            end else begin
                tick <= 0; // если ENABLE=0 или LOAD=1, сбрасываем счётчик тактов
            end
        end
    end

    // чтение (APB read)
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
