`timescale 1ns/1ps

module tb;

    localparam ADDR_WIDTH = 4;
    localparam DATA_WIDTH = 32;

    logic PCLK;
    logic PRESETn;
    logic PSEL, PENABLE, PWRITE;
    logic [ADDR_WIDTH-1:0] PADDR;
    logic [DATA_WIDTH-1:0] PWDATA;
    logic [DATA_WIDTH-1:0] PRDATA;
    logic PREADY, PSLVERR;

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

    initial begin
        PCLK = 0;
        forever #5 PCLK = ~PCLK;
    end

    initial begin
        $dumpfile("apb_downcounter.vcd");
        $dumpvars(0, tb);
    end

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
        @(posedge PCLK);
    end
    endtask

    // Функция проверки команд из файла
    function string check_command();
        integer file;
        string command;
        begin
            file = $fopen("command.txt", "r");
            if (file != 0) begin
                if ($fscanf(file, "%s", command) == 1) begin
                    $fclose(file);
                    // Очищаем файл после чтения команды
                    file = $fopen("command.txt", "w");
                    $fclose(file);
                    return command;
                end
                $fclose(file);
            end
            return "";
        end
    endfunction

    initial begin
        logic [31:0] start_value = 30; //начальное значение
        string command;
        integer counter_changes = 0;
        
        $display("================================================");
        $display(">>> INTERACTIVE COUNTER CONTROL");
        $display(">>> HOW TO USE:");
        $display(">>> 2. Create file 'command.txt' in this folder");
        $display(">>> 3. Write one of these commands in the file:");
        $display(">>>    PAUSE  - stop counter");
        $display(">>>    RESUME - continue counter"); 
        $display(">>>    RESET  - restart from 10");
        $display(">>> 4. Save the file - counter will react!");
        $display("================================================");

        // Инициализация
        PRESETn = 0;
        PSEL = 0; PENABLE = 0; PWRITE = 0;
        PADDR = '0; PWDATA = '0;
        repeat (2) @(posedge PCLK);
        PRESETn = 1;
        repeat (2) @(posedge PCLK);

        // Запускаем счетчик
        $display(">>> STARTING COUNTER");
        apb_write('h4, start_value);
        apb_write('h0, 32'd3); // LOAD
        apb_write('h0, 32'd1); // ENABLE

        // Создаем пустой файл команд
        begin
            integer file = $fopen("command.txt", "w");
            $fclose(file);
        end

        // Главный цикл - работает 2 минуты
        while ($time < 120000000000) begin // 2 minutes
            // Проверяем команду каждые 100,000 тактов (быстро)
            command = check_command();
            
            if (command == "PAUSE") begin
                $display(">>> COMMAND RECEIVED: PAUSE");
                apb_write('h0, 32'd0);
                $display(">>> COUNTER PAUSED at value %0d", dut.reg_cur);
            end
            else if (command == "RESUME") begin
                $display(">>> COMMAND RECEIVED: RESUME");
                apb_write('h0, 32'd1);
                $display(">>> COUNTER RESUMED from value %0d", dut.reg_cur);
            end
            else if (command == "RESET") begin
                $display(">>> COMMAND RECEIVED: RESET");
                apb_write('h0, 32'd3);
                apb_write('h0, 32'd1);
                $display(">>> COUNTER RESET");
            end
            
            // Небольшая задержка между проверками команд
            repeat(100000) @(posedge PCLK);
        end

        $display(">>> SIMULATION FINISHED (2 minutes passed)");
        $finish;
    end

    // Процесс для отображения изменений счетчика
    initial begin
        logic [31:0] last_displayed = 0;
        forever begin
            @(posedge PCLK);
            if (dut.reg_cur != last_displayed) begin
                if (dut.reg_ctrl[0]) begin
                    //$display("    [Time: %0t] Counter: %0d", $time, dut.reg_cur);
                    $display("    Counter: %0d", dut.reg_cur);
                end else begin
                    $display("    [PAUSED at %0d]", last_displayed);
                end
                last_displayed = dut.reg_cur;
            end
        end
    end

endmodule