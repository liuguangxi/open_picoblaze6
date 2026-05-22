# Runtime arguments
set TESTFILE rec_fn_test.hex
set RUNCYC 10000


# Run simulation
if {[file exists work]} {
    vdel -lib work -all
}
vlib work

vlog -f script/filelist.f

vsim -l run.log tb_opb6_basic +TESTFILE=$TESTFILE +RUNCYC=$RUNCYC

run -all
