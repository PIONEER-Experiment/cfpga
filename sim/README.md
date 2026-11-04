# Channel firmware simulations (Icarus Verilog, `iverilog -g2012`)

`tb_fill_boundary.sv` — joint test of `self_trigger`, `enable_sm_selftrigc`, `circ_buf_to_ddr3_sm_selftrigc`
(with the parity FIFO as in `adc_acq_top_selftrigc`) and the master's `channel_triggerc_receiver`
(`mfpga_stc/hdl/selftrigc_mode_only`). Pulses at random phases across readout boundaries; every fill's
master count must equal the number of waveforms the channel stored, and no pulse may be lost.

6.8.1 keeps the trigger line inside the channel (it paces the fill close) but no longer sends it; the
master's receiver went in master 6.8.0, so take it from the 6.7.3 tree for this test:

    git -C ../../mfpga_stc show a294a4a:hdl/selftrigc_mode_only/channel_triggerc_receiver.v > channel_triggerc_receiver.v
    iverilog -g2012 -o sim tb_fill_boundary.sv ../hdl/self_trigger.v enable_sm_sim.sv \
        ../hdl/circ_buf_to_ddr3_sm_selftrigc.v channel_triggerc_receiver.v ../hdl/sync_2stage.v
    vvp sim ... +hold=N +gap=M             # trigger-line pulse shape (default 24 / 24, the 6.7.0 values)
    vvp sim +seed=5 +burst +bdelay=10      # random run, bursts at 80% of the trigger-line rate, 10 ns board delay
    vvp sim +sweep +bdelay=30              # one pulse per fill swept from 80 clocks before to 240 after the boundary
    vvp sim +pairs +minsep=20 [+level=1]   # pulse pairs at swept spacing: minimum separation and re-arm mode
    vvp sim +seed=3 +noise +bdelay=10      # pulses faster than the trigger line: refusals expected, counts must still agree
    vvp sim +seed=4 +burst +backlog=6 +wfm_bursts=100   # slow reader, trigger FIFO backs up: FIFO back-pressure path
    vvp sim +seed=8 +nflen=60              # a 1.5 us new_fill level must close one fill, not two
    vvp sim +seed=9 +nflen=1 +bdelay=10    # a 25 ns new_fill level must not be missed
    vvp sim +seed=7 +burst +wfm_bursts=60 +bdelay=20   # slow reader at the default back-pressure threshold

The testbench raises a boundary only after the master has seen the previous done (as the acquisition
controller does), and then as soon as asked, i.e. back-to-back; `+freerun` drops that wait and is
informational only (boundaries during a close are absorbed, so fills < boundaries there).

Icarus does not accept two SystemVerilog constructs that Vivado does; make `enable_sm_sim.sv` from
`../hdl/enable_sm_selftrigc.sv` by rewriting the two enum ternaries
(`NS = enable_acquisition ? X : IDLE;` -> `if (enable_acquisition) NS = X; else NS = IDLE;`).

`tb_rd_fill.v` — `cc_rd_fill_sm` first-event interlock: the read-fill command arriving before the fill
header is written must wait (not error), and time out only if no header ever comes.

    iverilog -g2012 -o sim tb_rd_fill.v ../hdl/cc_rd_fill_sm.v ../hdl/sync_2stage.v && vvp sim

`tb_chan_error.v` — `chan_error_selftrigc` (6.6.10): sets from the three clock domains become sticky bits
(register 0x37) and the {lost data, fault, cause code} word of the fill header; the clear and the full reset
empty them.

    iverilog -g2012 -o sim tb_chan_error.v ../hdl/chan_error_selftrigc.v && vvp sim

`tb_peek_hdr.v` — `cc_peek_hdr_sm` (6.7.0): the peek command carries the fill number the master expects;
the reply is RSN, CC, the four header words (tlast on the last) and the header stays in the FIFO; a header
for an older fill is popped (once, with a settle wait) and reported in CC bit 8; back-pressure; the
time-out reply; a malformed command.

    iverilog -g2012 -o sim tb_peek_hdr.v ../hdl/cc_peek_hdr_sm.v && vvp sim
