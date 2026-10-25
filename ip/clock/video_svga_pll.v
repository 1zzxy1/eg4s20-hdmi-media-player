// Diagnostic-only clocks, using the existing 1GHz VCO / 25MHz PFD setup.
// C0 is the 50MHz feedback clock; C1 = 40MHz pixels; C2 = 200MHz serializer.
// The game video_pll is deliberately independent of this experiment.
`timescale 1ns/100fs
module video_svga_pll(
    input wire refclk,reset,
    output wire locked,pixel_clk,serial_clk
);
    wire feedback_raw,feedback_clk,pixel_raw,open4,open3;
    EG_LOGIC_BUFG feedback_buffer(.i(feedback_raw),.o(feedback_clk));
    EG_LOGIC_BUFG pixel_buffer(.i(pixel_raw),.o(pixel_clk));
    EG_PHY_PLL #(
        .DPHASE_SOURCE("DISABLE"),.DYNCFG("DISABLE"),.FIN("50.000000"),
        .FEEDBK_MODE("NORMAL"),.FEEDBK_PATH("CLKC0_EXT"),
        .STDBY_ENABLE("DISABLE"),.PLLRST_ENA("ENABLE"),.SYNC_ENABLE("DISABLE"),
        .GMC_GAIN(2),.ICP_CURRENT(9),.KVCO(2),.LPF_CAPACITOR(1),.LPF_RESISTOR(8),
        .REFCLK_DIV(2),.FBCLK_DIV(2),
        .CLKC0_ENABLE("ENABLE"),.CLKC0_DIV(20),.CLKC0_CPHASE(19),.CLKC0_FPHASE(0),
        .CLKC1_ENABLE("ENABLE"),.CLKC1_DIV(25),.CLKC1_CPHASE(24),.CLKC1_FPHASE(0),
        .CLKC2_ENABLE("ENABLE"),.CLKC2_DIV(5),.CLKC2_CPHASE(4),.CLKC2_FPHASE(0)
    ) pll_inst(
        .refclk(refclk),.reset(reset),.stdby(1'b0),.extlock(locked),
        .load_reg(1'b0),.psclk(1'b0),.psdown(1'b0),.psstep(1'b0),.psclksel(3'b0),.psdone(),
        .dclk(1'b0),.dcs(1'b0),.dwe(1'b0),.di(8'b0),.daddr(6'b0),.do(),
        .fbclk(feedback_clk),.clkc({open4,open3,serial_clk,pixel_raw,feedback_raw})
    );
endmodule
