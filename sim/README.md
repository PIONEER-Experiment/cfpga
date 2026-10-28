# Channel firmware simulations (Icarus Verilog, `iverilog -g2012`)

`tb_fill_boundary.sv` — joint test of `self_trigger`, `enable_sm_selftrigc`, `circ_buf_to_ddr3_sm_selftrigc`
(with the parity FIFO as in `adc_acq_top_selftrigc`) and the master's `channel_triggerc_receiver`
(`mfpga_stc/hdl/selftrigc_mode_only`). Pulses at random phases across readout boundaries; every fill's
master count must equal the number of waveforms the channel stored, and no pulse may be lost.

    iverilog -g2012 -o sim tb_fill_boundary.sv ../hdl/self_trigger.v enable_sm_sim.sv \
        ../hdl/circ_buf_to_ddr3_sm_selftrigc.v ../../mfpga_stc/hdl/selftrigc_mode_only/channel_triggerc_receiver.v ../hdl/sync_2stage.v
    vvp sim +seed=5 +burst +bdelay=10      # random run, bursts at 80% of the trigger-line rate, 10 ns board delay
    vvp sim +sweep +bdelay=30              # one pulse per fill swept from 80 clocks before to 240 after the boundary
    vvp sim +pairs +minsep=20 [+level=1]   # pulse pairs at swept spacing: minimum separation and re-arm mode

Icarus does not accept two SystemVerilog constructs that Vivado does; make `enable_sm_sim.sv` from
`../hdl/enable_sm_selftrigc.sv` by rewriting the two enum ternaries
(`NS = enable_acquisition ? X : IDLE;` -> `if (enable_acquisition) NS = X; else NS = IDLE;`).

`tb_rd_fill.v` — `cc_rd_fill_sm` first-event interlock: the read-fill command arriving before the fill
header is written must wait (not error), and time out only if no header ever comes.

    iverilog -g2012 -o sim tb_rd_fill.v ../hdl/cc_rd_fill_sm.v ../hdl/sync_2stage.v && vvp sim
