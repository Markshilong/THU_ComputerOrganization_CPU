`include "../../defines.svh"

module bitcounter (
    input word_t value,
    output word_t clz_result,
    output word_t ctz_result,
    output word_t cntone_result
);

logic[3:0] clz_count3, clz_count2, clz_count1, clz_count0;
clz_byte clz_byte3(.val(value[31:24]), .count(clz_count3));
clz_byte clz_byte2(.val(value[23:16]), .count(clz_count2));
clz_byte clz_byte1(.val(value[15:8]),  .count(clz_count1));
clz_byte clz_byte0(.val(value[7:0]),   .count(clz_count0));
always_comb begin
    if (clz_count3 != 4'd8) begin
        clz_result = { 29'b0, clz_count3[2:0] };
    end else if(clz_count2 != 4'd8) begin
        clz_result = { 27'b0, 2'b01, clz_count2[2:0] };
    end else if(clz_count1 != 4'd8) begin
        clz_result = { 27'b0, 2'b10, clz_count1[2:0] };
    end else begin
        clz_result = { 27'b0, 2'b11, 3'b0 } + { 28'b0, clz_count0 };
    end
end

logic[3:0] ctz_count3, ctz_count2, ctz_count1, ctz_count0;
ctz_byte ctz_byte3(.val(value[31:24]), .count(ctz_count3));
ctz_byte ctz_byte2(.val(value[23:16]), .count(ctz_count2));
ctz_byte ctz_byte1(.val(value[15:8]),  .count(ctz_count1));
ctz_byte ctz_byte0(.val(value[7:0]),   .count(ctz_count0));
always_comb begin
    if (ctz_count0 != 4'd8) begin
        ctz_result = { 29'b0, ctz_count0[2:0] };
    end else if(clz_count1 != 4'd8) begin
        ctz_result = { 27'b0, 2'b01, clz_count1[2:0] };
    end else if(clz_count2 != 4'd8) begin
        ctz_result = { 27'b0, 2'b10, clz_count2[2:0] };
    end else begin
        ctz_result = { 27'b0, 2'b11, 3'b0 } + { 28'b0, clz_count3 };
    end
end

always_comb begin
    cntone_result = '0;  
    foreach(value[idx]) begin
        cntone_result += value[idx];
    end
end

endmodule



module clz_byte(
    input  logic[7:0] val,
    output logic[3:0] count
);
always_comb begin
    casez(val)
        8'b1???????: count = 4'd0;
        8'b01??????: count = 4'd1;
        8'b001?????: count = 4'd2;
        8'b0001????: count = 4'd3;
        8'b00001???: count = 4'd4;
        8'b000001??: count = 4'd5;
        8'b0000001?: count = 4'd6;
        8'b00000001: count = 4'd7;
        8'b00000000: count = 4'd8;
    endcase
end
endmodule


module ctz_byte(
    input  logic[7:0] val,
    output logic[3:0] count
);
always_comb begin
    casez(val)
        8'b???????1: count = 4'd0;
        8'b??????10: count = 4'd1;
        8'b?????100: count = 4'd2;
        8'b????1000: count = 4'd3;
        8'b???10000: count = 4'd4;
        8'b??100000: count = 4'd5;
        8'b?1000000: count = 4'd6;
        8'b10000000: count = 4'd7;
        8'b00000000: count = 4'd8;
    endcase
end
endmodule

