`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: USTC ESLAB
// Engineer: Huang Yifan (hyf15@mail.ustc.edu.cn)
// 
// Design Name: RV32I Core
// Module Name: Hazard Module
// Tool Versions: Vivado 2017.4.1
// Description: Hazard Module is used to control flush, bubble and bypass
// 
//////////////////////////////////////////////////////////////////////////////////

//  功能说明
    //  识别流水线中的数据冲突，控制数据转发，和flush、bubble信号
// 输入
    // rst               CPU的rst信号
    // reg1_srcD         ID阶段的源reg1地址
    // reg2_srcD         ID阶段的源reg2地址
    // reg1_srcE         EX阶段的源reg1地址
    // reg2_srcE         EX阶段的源reg2地址
    // reg_dstE          EX阶段的目的reg地址
    // reg_dstM          MEM阶段的目的reg地址
    // reg_dstW          WB阶段的目的reg地址
    // br                是否branch
    // jalr              是否jalr
    // jal               是否jal
    // src_reg_en        指令中的源reg1和源reg2地址是否有效
    // wb_select         写回寄存器的值的来源（Cache内容或者ALU计算结果）
    // reg_write_en_MEM  MEM阶段的寄存器写使能信号
    // reg_write_en_WB   WB阶段的寄存器写使能信号
    // alu_src1          ALU操作数1来源：0表示来自reg1，1表示来自PC
    // alu_src2          ALU操作数2来源：2’b00表示来自reg2，2'b01表示来自reg2地址，2'b10表示来自立即数
// 输出
    // flushF            IF阶段的flush信号
    // bubbleF           IF阶段的bubble信号
    // flushD            ID阶段的flush信号
    // bubbleD           ID阶段的bubble信号
    // flushE            EX阶段的flush信号
    // bubbleE           EX阶段的bubble信号
    // flushM            MEM阶段的flush信号
    // bubbleM           MEM阶段的bubble信号
    // flushW            WB阶段的flush信号
    // bubbleW           WB阶段的bubble信号
    // op1_sel           ALU的操作数1来源：2'b00表示来自ALU转发数据，2'b01表示来自write back data转发，2'b10表示来自PC，2'b11表示来自reg1
    // op2_sel           ALU的操作数2来源：2'b00表示来自ALU转发数据，2'b01表示来自write back data转发，2'b10表示来自reg2地址，2'b11表示来自reg2或立即数
    // reg2_sel          reg2的来源
// 实验要求
    // 补全模块


module HarzardUnit(
    input wire rst,
    input wire [4:0] reg1_srcD, reg2_srcD, reg1_srcE, reg2_srcE, reg_dstE, reg_dstM, reg_dstW,
    input wire br, jalr, jal,
    input wire [1:0] src_reg_en,
    input wire wb_select,
    input wire reg_write_en_MEM,
    input wire reg_write_en_WB,
    input wire alu_src1,
    input wire [1:0] alu_src2,
    output reg flushF, bubbleF, flushD, bubbleD, flushE, bubbleE, flushM, bubbleM, flushW, bubbleW,
    output reg [1:0] op1_sel, op2_sel, reg2_sel
    );

    // TODO: Complete this module
    //产生flush和bubble信号
    always@(*)
    begin
        if(rst)//cpu restart，flush全部部件
            {bubbleF,flushF,bubbleD,flushD,bubbleE,flushE,bubbleM,flushM,bubbleW,flushW} <= 10'b0101010101;
        else if(br | jalr)//分支和jalr跳转指令，均在ex阶段得到有效地址，因此flush D和E
            {bubbleF,flushF,bubbleD,flushD,bubbleE,flushE,bubbleM,flushM,bubbleW,flushW} <= 10'b0001010000;
        else if(jal)//单纯jal指令，id阶段得到有效地址，因此只flush D
            {bubbleF,flushF,bubbleD,flushD,bubbleE,flushE,bubbleM,flushM,bubbleW,flushW} <= 10'b0001000000;
        else if(wb_select & ((reg_dstE==reg1_srcD) || (reg_dstE==reg2_srcD)))
            //此时为cache内容写入寄存器单元（即LW类指令），若写入的目的寄存器是执行阶段的源寄存器，需要bubble流水线，同时flush ex阶段的内容
            {bubbleF,flushF,bubbleD,flushD,bubbleE,flushE,bubbleM,flushM,bubbleW,flushW} <= 10'b1010010000;
        else
            {bubbleF,flushF,bubbleD,flushD,bubbleE,flushE,bubbleM,flushM,bubbleW,flushW} <= 10'b0000000000;
    end

    //产生forward信号
    //首先产生regsrc1
    always@(*)
    begin
        if( (reg_write_en_MEM!=1'b0) && (src_reg_en[1]!=1'b0) && (reg_dstM==reg1_srcE) && (reg_dstM!=5'b00000) )
            op1_sel<=2'b00;//采用aluout
        else if( (reg_write_en_WB!=1'b0)  && (src_reg_en[1]!=1'b0) && (reg_dstW==reg1_srcE) && (reg_dstW!=5'b00000))
            op1_sel<=2'b01;//来自write back
        else if(alu_src1==1'b1)//来自pc
            op1_sel<=2'b10;
        else
            op1_sel<=2'b11;//来自reg
    end
    //产生regsrc2的forward信号
    always@(*)
    begin
        if( (reg_write_en_MEM!=1'b0) && (src_reg_en[0]!=1'b0) && (reg_dstM==reg2_srcE) && (reg_dstM!=5'b00000) )
            op2_sel<=2'b00;//采用aluout
        else if( (reg_write_en_WB!=1'b0)  && (src_reg_en[0]!=1'b0) && (reg_dstW==reg2_srcE) && (reg_dstW!=5'b00000))
            op2_sel<=2'b01;//来自write back
        else if((alu_src2==2'b01))//来自地址
            op2_sel<=2'b10;
        else
            op2_sel<=2'b11;//来自reg或imm
    end
    always@(*)
    begin
        if( (reg_write_en_MEM!=1'b0) && (src_reg_en[0]!=1'b0) && (reg_dstM==reg2_srcE) && (reg_dstM!=5'b00000) )
            reg2_sel<=2'b00;//采用aluout
        else if( (reg_write_en_WB!=1'b0)  && (src_reg_en[0]!=1'b0) && (reg_dstW==reg2_srcE) && (reg_dstW!=5'b00000))
            reg2_sel<=2'b01;//来自write back
        else
            reg2_sel<=2'b10;//来自reg
    end
endmodule

//完成实现