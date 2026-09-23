module load_store_decoder(
    input  [31:0] alu_result_address,
    input  [2:0]  f3,
    input  [31:0] reg_read,
    output reg [3:0]  byte_enable,
    output reg [31:0] data
);
wire [1:0] offset;
assign offset = alu_result_address[1:0];
localparam F3_BYTE       = 3'b000;
localparam F3_HALFWORD   = 3'b001;
localparam F3_WORD       = 3'b010;
localparam F3_BYTE_U     = 3'b100;
localparam F3_HALFWORD_U = 3'b101;
always @(*) begin
    byte_enable = 4'b0000;
    data = 32'd0;
    case (f3)
        F3_BYTE, F3_BYTE_U: begin
            case (offset)
                2'b00: begin byte_enable = 4'b0001; data = reg_read & 32'h000000FF; end
                2'b01: begin byte_enable = 4'b0010; data = (reg_read & 32'h000000FF) << 8; end
                2'b10: begin byte_enable = 4'b0100; data = (reg_read & 32'h000000FF) << 16; end
                2'b11: begin byte_enable = 4'b1000; data = (reg_read & 32'h000000FF) << 24; end
                default: begin byte_enable = 4'b0000; data = 32'd0; end
            endcase
        end
        F3_WORD: begin
            byte_enable = (offset == 2'b00) ? 4'b1111 : 4'b0000;
            data = reg_read;
        end
        F3_HALFWORD, F3_HALFWORD_U: begin
            case (offset)
                2'b00: begin byte_enable = 4'b0011; data = reg_read & 32'h0000FFFF; end
                2'b10: begin byte_enable = 4'b1100; data = (reg_read & 32'h0000FFFF) << 16; end
                default: begin byte_enable = 4'b0000; data = 32'd0; end
            endcase
        end
        default: begin
            byte_enable = 4'b0000;
            data = 32'd0;
        end
    endcase
end
endmodule
