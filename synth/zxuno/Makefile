
CP = cp

DESIGN = zxuno
DEVICE_NAME = xc6slx9
DEVICE_PACKAGE = tqg144
DEVICE_SPEED = 2
UCF_FILE = ../../src/syn-zxuno/zxuno_pins_v4.ucf

# Make all runs to place & route
all: pld
	$(CP) $(DESIGN).bit ../../_BINs
	$(CP) $(DESIGN).pld ../../_BINs/COREX.ZX1

include ../makefile_xilinx.inc
