# Runtime arguments
set TESTFILE rec_fn_int_test.hex
set RUNCYC 5000
set SLEEPCYC 2
set INTCYC 200


# Run simulation
if {[file exists work]} {
    vdel -lib work -all
}
vlib work

vlog -f script/filelist.f

vsim -l run.log tb_opb6_full +TESTFILE=$TESTFILE +RUNCYC=$RUNCYC +SLEEPCYC=$SLEEPCYC +INTCYC=$INTCYC

run -all
