module reset_control
(
 input wire  clk,
 input wire  reset_button_n,
 output wire reset_n
);

   reg [5:0] reset_count = 0;

   assign reset_n = &reset_count;

   always @(posedge clk)
     if (reset_button_n)
       reset_count <= reset_count + !reset_n;
     else
       reset_count <= 'b0;

endmodule
