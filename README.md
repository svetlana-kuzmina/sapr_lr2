# САПР — Лабораторная работа №2

**Авторы:** Кузьмина Светлана, Пережог Степан  
**Группа:** М3О-410Б-22

Данный проект представляет собой лабораторую работу №2 по курсу "Автоматизация проектирования"

## Countdown counter

**How to Compiler**  
iverilog -g2012 -o tb.vvp tb_apb_downcounter.sv apb_downcounter.sv

**How to Run simulation**  
vvp tb.vvp  
vvp tb.vvp +START=25

**How to view waveforms**  
gtkwave apb_downcounter.vcd
