
CP = cp

#
DESIGN = qmxc6slx16
DEVICE_NAME = xc6slx16
DEVICE_PACKAGE = ftg256
DEVICE_SPEED = 2
UCF_FILE = ../../src/syn-qmxc6slx16/qmxc6slx16_pins.ucf

# Make all runs to place & route
all: pld
	$(CP) $(DESIGN).bit $(DESIGN).pld ../../_BINs

include ../makefile_xilinx.inc
