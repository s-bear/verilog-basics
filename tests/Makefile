
#list verilog files, separate into test and src files
#two patterns are included for matching test files: test% and %_tb.v

V_FILES = $(wildcard *.v)
TEST_FILES = $(filter test% %_tb.v,$(V_FILES))
SRC_FILES = $(filter-out test% %_tb.v,$(V_FILES))
MODULE_DIRS = ..

VC = iverilog
VCFLAGS = -v -Wall $(addprefix -y,$(MODULE_DIRS))
CHECKFLAGS = -Wall $(addprefix -y,$(MODULE_DIRS))

SIM = vvp
SIMFLAGS = -v
SIMARGS = -fst

#filenames for compiled testbenches, simulation logs
TEST_OUT_FILES = $(addsuffix .vvp,$(basename $(TEST_FILES)))
SIM_LOG_FILES = $(addsuffix .log,$(basename $(TEST_FILES)))

.PHONY: check sim clean

check: $(V_FILES)
	for tb in $(TEST_FILES); do \
	  $(VC) $(CHECKFLAGS) -tnull $$tb; \
	done

sim: $(SIM_LOG_FILES)

clean: 
	rm -f *.vvp *.log *.fst

#this rule for building test benches assumes that the test benches
# do not depend on each other
$(TEST_OUT_FILES): %.vvp: %.v $(SRC_FILES)
	$(VC) $(VCFLAGS) -tvvp -o $@ $<

$(SIM_LOG_FILES): %.log: %.vvp
	$(SIM) $(SIMFLAGS) -l $@ $^ $(SIMARGS)
