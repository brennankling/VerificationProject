module clkgen(output logic clock=0, input run_clock, logic [31:0] clock_period);
  always begin
    #(clock_period/2);
    clock = (run_clock == 1) ? ~clock : 0;
  end
endmodule
