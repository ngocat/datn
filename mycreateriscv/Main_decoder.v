module main_decoder(
   input [6:0] opcode,
input [2:0] funct3,
input [6:0] funct7,
output  Branch, RegWrite, ALUSrc, MemWrite, Jump,
output [1:0] ALUOp,SecondPC,ResultSrc,
output [2:0]ImmSrc

    );
reg [13:0] controls;
 always @(*) begin
    controls = 14'b0_______________________000_0____00______0____00______0_______0_____00;
        case (opcode)
                                //reg/imm/mem/result/branch/aluop/alusource/jump/second
            7'b0000011: controls = 14'b1___000_0____01______0____00______1_______0_____xx; // load (I-type)
            7'b0010011: begin 
                case(funct3)
                    3'b001: begin
                        controls = (funct7==7'b0000000)? 
                                    14'b1___000_0____00______0____10______1_______0_____xx:
                                    14'b0___000_0____00______0____10______1_______0_____xx; // slli
                            end
                    3'b101: begin
                        controls = ((funct7==7'b0000000) | (funct7==7'b0100000))?
                                    14'b1___000_0____00______0____10______1_______0_____xx:
                                    14'b0___000_0____00______0____10______1_______0_____xx; // srli/srai
                    end
                    default:controls=14'b1___000_0____00______0____10______1_______0_____xx;
                endcase
             end
            //s
            7'b0100011: controls = 14'b0___001_1____xx______0____00______1_______0_____xx; 
            //r
            7'b0110011: controls = 14'b1___xxx_0____00______0____10______0_______0_____xx; 
            // b
            7'b1100011: controls = 14'b0___010_0____xx______1____01______0_______0_____00;
            // j _jalr
            7'b1101111: controls = 14'b1___011_0____10______0____xx______x_______1_____00;   //jal
            7'b1100111: controls = 14'b1___000_0____10______0____xx______x_______1_____10;//jalr
            //u
            7'b0110111: controls = 14'b1___100_0____11______0____xx______x_______0_____01; //lui: SecondPC=01 -> immediate
            7'b0010111: controls = 14'b1___100_0____11______0____xx______x_______0_____00; //auipc: SecondPC=00 -> pc+imm [FIXED]
            default: controls = 14'b0___000_0____00______0____00______0_______0_____00; // [FIXED: added colon]
        endcase
    end
assign {RegWrite,ImmSrc, MemWrite, ResultSrc, Branch, ALUOp,ALUSrc, Jump,SecondPC} = controls;
endmodule
