module reader(
    input  [31:0] mem_data,
    input  [3:0]  be_mask,
    input  [2:0]  f3,
    output reg [31:0] wb_data,
    output reg        valid
);
reg [31:0] masked_data; 
reg [31:0] raw_data; 
wire       sign_extend;
assign sign_extend = ~f3[2];
localparam F3_BYTE       = 3'b000;
localparam F3_HALFWORD   = 3'b001;
localparam F3_WORD       = 3'b010;
localparam F3_BYTE_U     = 3'b100;
localparam F3_HALFWORD_U = 3'b101;
always @(*) begin
    masked_data = 32'd0;
    if (be_mask[0]) masked_data[7:0]   = mem_data[7:0];
    if (be_mask[1]) masked_data[15:8]  = mem_data[15:8];
    if (be_mask[2]) masked_data[23:16] = mem_data[23:16];
    if (be_mask[3]) masked_data[31:24] = mem_data[31:24];
end
always @(*) begin
    raw_data = 32'd0;
    case (f3)
        F3_WORD: raw_data = masked_data;
        F3_BYTE, F3_BYTE_U: begin
            case (be_mask)
                4'b0001: raw_data = masked_data;
                4'b0010: raw_data = masked_data >> 8;
                4'b0100: raw_data = masked_data >> 16;
                4'b1000: raw_data = masked_data >> 24;
                default: raw_data = 32'd0;
            endcase
        end
        F3_HALFWORD, F3_HALFWORD_U: begin
            case (be_mask)
                4'b0011: raw_data = masked_data;
                4'b1100: raw_data = masked_data >> 16;
                default: raw_data = 32'd0;
            endcase
        end
        default: raw_data = 32'd0;
    endcase
end
always @(*) begin
    wb_data = 32'b0;
    case (f3)
        F3_WORD: wb_data = raw_data;
        F3_BYTE, F3_BYTE_U:
            wb_data = sign_extend ? {{24{raw_data[7]}}, raw_data[7:0]} : raw_data;
        F3_HALFWORD, F3_HALFWORD_U:
            wb_data = sign_extend ? {{16{raw_data[15]}}, raw_data[15:0]} : raw_data;
        default: wb_data = raw_data;
    endcase
    valid = |be_mask;
end
endmodule
