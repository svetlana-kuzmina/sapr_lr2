`timescale 1ns/1ps
module tb;

    localparam ADDR_WIDTH = 4;
    localparam DATA_WIDTH = 32;

    // APB сигналы
    logic PCLK;
    logic PRESETn;
    logic PSEL, PENABLE, PWRITE;
    logic [ADDR_WIDTH-1:0] PADDR;
    logic [DATA_WIDTH-1:0] PWDATA;
    logic [DATA_WIDTH-1:0] PRDATA;
    logic PREADY, PSLVERR;

    //DUT (Device Under Test) .сигнал_модуля(сигнал_tb)
    apb_downcounter #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .PCLK(PCLK),
        .PRESETn(PRESETn),
        .PSEL(PSEL),
        .PENABLE(PENABLE),
        .PWRITE(PWRITE),
        .PADDR(PADDR),
        .PWDATA(PWDATA),
        .PRDATA(PRDATA),
        .PREADY(PREADY),
        .PSLVERR(PSLVERR)
    );

    // тактовый сигнал
    initial begin
        PCLK = 0;
        forever #5 PCLK = ~PCLK; // период 10 нс → частота 100 МГц
    end

    // Dump waveform for GTKWave
    initial begin
        $dumpfile("apb_downcounter.vcd");
        $dumpvars(0, tb);
    end

    // APB запись: сначала setup phase (PSEL=1, PENABLE=0), потом enable phase (PENABLE=1)
    task apb_write(input logic [ADDR_WIDTH-1:0] addr, input logic [DATA_WIDTH-1:0] data);
    begin
        PSEL    = 1;
        PENABLE = 0;
        PWRITE  = 1;
        PADDR   = addr;
        PWDATA  = data;
        @(posedge PCLK);
        PENABLE = 1;
        @(posedge PCLK);
        PSEL    = 0;
        PENABLE = 0;
        PWRITE  = 0;
        PADDR   = '0;
        PWDATA  = '0;
        @(posedge PCLK);
    end
    endtask

    task apb_read(input logic [ADDR_WIDTH-1:0] addr, output logic [DATA_WIDTH-1:0] data_out);
    begin
        PSEL    = 1;
        PENABLE = 0;
        PWRITE  = 0;
        PADDR   = addr;
        @(posedge PCLK);
        PENABLE = 1;
        @(posedge PCLK);
        data_out = PRDATA;
        PSEL    = 0;
        PENABLE = 0;
        PADDR   = '0;
        @(posedge PCLK);
    end
    endtask

    // Хранят данные, прочитанные с помощью apb_read
    logic [31:0] ctrl_val;
    logic [31:0] max_val;
    logic [31:0] cur_val;
    logic [31:0] tmp;

    // Основной тест
    initial begin
        logic [31:0] start_value;

        // Получение значения из командной строки
        if ($value$plusargs("START=%d", start_value)) begin
            $display(">>> Value from command line: %0d", start_value);
        end else begin
            // Значение по умолчанию, если аргумент не указан
            start_value = 32'd15;
            $display(">>> Argument not entered. Using default value: %0d", start_value);
            $display(">>> For using another value - enter: vvp tb.vvp +START=value");
        end

        // Проверка корректности значения
        if (start_value > 1000) begin
            $display(">>> WARNING: valuse %0d very big, using 100", start_value);
            start_value = 32'd100;
        end

        $display("\n>>> APB Downcounter <<<");
        $display(">>> Setting counter: %0d", start_value);

        // Инициализация
        PRESETn = 0;
        PSEL = 0; PENABLE = 0; PWRITE = 0;
        PADDR = '0; PWDATA = '0;
        ctrl_val = '0;
        max_val = '0;
        cur_val = '0;

        repeat (2) @(posedge PCLK);
        PRESETn = 1;
        repeat (2) @(posedge PCLK);
        $display("-------------------------- Start of test --------------------------");

        //запись MAX = введенное значение
        apb_write('h4, start_value);
        apb_read('h4, max_val);

        //CTRL (ENABLE + LOAD) → CUR=MAX
        apb_write('h0, 32'd3);
        apb_read('h0, ctrl_val);
        apb_read('h8, cur_val);

        // Снимаем LOAD, оставляем ENABLE → начинается обратный счёт
        apb_write('h0, 32'd1);
        apb_read('h0, ctrl_val);

        // Наблюдаем работу счётчика
        $display("-------------------------- Counting process --------------------------");
        repeat (start_value + 1) begin
            @(posedge PCLK);
            apb_read('h8, tmp);
            apb_read('h0, ctrl_val);
            apb_read('h4, max_val);
        end

        // Отключаем счётчик
        $display("-------------------------- Disable counting (CTRL = 0)--------------------------");
        apb_write('h0, 32'd0);
        apb_read('h0, ctrl_val);
        apb_read('h8, cur_val);

        #20;
        $display("-------------------------- End of test --------------------------");
        $finish;
    end

    // выводим значения сигналов при любом их изменении
    initial begin
        $display("-------------------------- Downcounter Monitor --------------------------");
        $monitor("PSEL=%b  PENABLE=%b  PWRITE=%b  PADDR=0x%0h  PWDATA=%0d  PRDATA=%0d  CTRL=%0d  MAX=%0d  CUR=%0d", PSEL, PENABLE, PWRITE, PADDR, PWDATA, PRDATA, ctrl_val, max_val, tmp);
    end

endmodule
