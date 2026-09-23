module countdown_timer (
    input  wire        clk,
    input  wire        reset_n,

    input  wire        cdt_sel,
    input  wire [31:0] cdt_data_i,
    input  wire [3:0]  we,

    output wire        cdt_ready,
    output wire [31:0] cdt_data_o
);

    localparam IDLE = 2'b00;
    localparam WAIT = 2'b01;
    localparam DONE = 2'b10;
    localparam HOLD = 2'b11;

    reg [1:0]  state;
    reg [31:0] counter;

    assign cdt_data_o = counter;
    assign cdt_ready  = (state == DONE);

    // FSM tạo tín hiệu ready cho bus
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state <= IDLE;
        end
        else begin
            case (state)
                IDLE: begin
                    if (cdt_sel)
                        state <= WAIT;
                    else
                        state <= IDLE;
                end

                WAIT: begin
                    if (cdt_sel)
                        state <= DONE;
                    else
                        state <= IDLE;
                end

                DONE: begin
                    if (cdt_sel)
                        state <= HOLD;
                    else
                        state <= IDLE;
                end

                HOLD: begin
                    if (cdt_sel)
                        state <= HOLD;
                    else
                        state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    // Thanh ghi đếm ngược
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            counter <= 32'd0;
        end
        else begin
            if (cdt_sel && (|we)) begin
                if (we[3]) counter[31:24] <= cdt_data_i[31:24];
                if (we[2]) counter[23:16] <= cdt_data_i[23:16];
                if (we[1]) counter[15:8]  <= cdt_data_i[15:8];
                if (we[0]) counter[7:0]   <= cdt_data_i[7:0];
            end
            else if (counter != 32'd0) begin
                counter <= counter - 32'd1;
            end
        end
    end

endmodule