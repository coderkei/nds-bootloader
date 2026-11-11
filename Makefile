#---------------------------------------------------------------------------------
.SUFFIXES:
#---------------------------------------------------------------------------------
# BlocksDS / Wonderful Toolchain. Tools are called by explicit path, never by
# bare name, so that nothing is picked up from a devkitPro installation.
#---------------------------------------------------------------------------------
export BLOCKSDS				?=	/opt/blocksds/core
export WONDERFUL_TOOLCHAIN	?=	/opt/wonderful

ifeq ($(wildcard $(BLOCKSDS)/libs/libnds/include/nds.h),)
$(error "BlocksDS libnds headers not found under BLOCKSDS=$(BLOCKSDS). Build from the Wonderful Toolchain shell or set BLOCKSDS)
endif

PREFIX	:=	$(WONDERFUL_TOOLCHAIN)/toolchain/gcc-arm-none-eabi/bin/arm-none-eabi-

ifeq ($(VERBOSE),1)
V		:=
else
V		:=	@
endif

#---------------------------------------------------------------------------------
# BUILD is the directory where object files & intermediate files will be placed
# SOURCES is a list of directories containing source code
# INCLUDES is a list of directories containing extra header files
#---------------------------------------------------------------------------------
TARGET		:=	load
BUILD		?=	build
SOURCES		:=	source source/patches 
INCLUDES	:=	build
SPECS		:=  specs
 
#---------------------------------------------------------------------------------
# options for code generation
#---------------------------------------------------------------------------------
ARCH	:=	-mthumb -mthumb-interwork

CFLAGS	:=	-g -Wall -Os -std=gnu17\
			-mcpu=arm7tdmi -mtune=arm7tdmi -fomit-frame-pointer\
			-ffast-math \
			$(ARCH)

CFLAGS	+=	$(INCLUDE) $(EXTRA_CFLAGS) -DARM7 -D__NDS__

ASFLAGS	:=	-g $(ARCH) $(EXTRA_CFLAGS) $(INCLUDE)
LDFLAGS	=	-nostartfiles -T $(TOPDIR)/load.ld -Wl,--no-warn-rwx-segments -Wl,-z,noexecstack -g $(ARCH) -Wl,-Map,$(TARGET).map

LIBS	:= 

#---------------------------------------------------------------------------------
# list of directories containing libraries, this must be the top level containing
# include and lib
#---------------------------------------------------------------------------------
LIBDIRS	:=	$(BLOCKSDS)/libs/libnds
 
  
#---------------------------------------------------------------------------------
# no real need to edit anything past this point unless you need to add additional
# rules for different file extensions
#---------------------------------------------------------------------------------
ifneq ($(BUILD),$(notdir $(CURDIR)))
#---------------------------------------------------------------------------------
 
export TOPDIR	:=	$(CURDIR)
export LOADBIN	?=	$(CURDIR)/$(TARGET).bin
export LOADELF	:=	$(CURDIR)/$(TARGET).elf
export DEPSDIR	:=	$(CURDIR)/$(BUILD)

export VPATH	:=	$(foreach dir,$(SOURCES),$(CURDIR)/$(dir))
 
export CC		:=	$(PREFIX)gcc
export CXX		:=	$(PREFIX)g++
export AR		:=	$(PREFIX)ar
export OBJCOPY	:=	$(PREFIX)objcopy
 
CFILES		:=	$(foreach dir,$(SOURCES),$(notdir $(wildcard $(dir)/*.c)))
CPPFILES	:=	$(foreach dir,$(SOURCES),$(notdir $(wildcard $(dir)/*.cpp)))
SFILES		:=	$(foreach dir,$(SOURCES),$(notdir $(wildcard $(dir)/*.s)))
 
export OFILES	:=	$(CPPFILES:.cpp=.o) $(CFILES:.c=.o) $(SFILES:.s=.o)
 
export INCLUDE	:=	$(foreach dir,$(INCLUDES),-I$(CURDIR)/$(dir)) \
					$(foreach dir,$(LIBDIRS),-I$(dir)/include) \
					-I$(CURDIR)/$(BUILD)
 
export LIBPATHS	:=	$(foreach dir,$(LIBDIRS),-L$(dir)/lib)

#---------------------------------------------------------------------------------
# use CC for linking standard C
#---------------------------------------------------------------------------------
export LD	:=	$(CC)
#---------------------------------------------------------------------------------

.PHONY: $(BUILD) clean
 
#---------------------------------------------------------------------------------
$(BUILD):
	@[ -d $@ ] || mkdir -p $@
	@$(MAKE) -C $(BUILD) -f $(CURDIR)/Makefile 
 
#---------------------------------------------------------------------------------
clean:
	@echo clean ...
	@rm -fr $(BUILD) *.elf *.bin
 
 
#---------------------------------------------------------------------------------
else
 
DEPENDS	:=	$(OFILES:.o=.d)

#---------------------------------------------------------------------------------
# compile rules (previously provided by devkitARM's base_rules)
#---------------------------------------------------------------------------------
%.arm.o: CFLAGS += -marm

%.o: %.c
	@echo $(notdir $<)
	$(V)$(CC) -MMD -MP -MF $(DEPSDIR)/$*.d $(CFLAGS) -c $< -o $@

%.o: %.s
	@echo $(notdir $<)
	$(V)$(CC) -MMD -MP -MF $(DEPSDIR)/$*.d -x assembler-with-cpp $(ASFLAGS) -c $< -o $@
 
#---------------------------------------------------------------------------------
# main targets
#---------------------------------------------------------------------------------
$(LOADBIN)	:	$(LOADELF)
	$(V)$(OBJCOPY) -O binary $< $@
	@echo built ... $(notdir $@)


$(LOADELF)	: $(OFILES)
	@echo linking $(notdir $@)
	$(V)$(LD)  $(LDFLAGS) $(OFILES) $(LIBPATHS) $(LIBS) -o $@

arm9mpu_reset.o: mpu_reset.bin

mpu_reset.bin: mpu_reset.elf
	$(OBJCOPY) -O binary $< $@

mpu_reset.elf: $(TOPDIR)/arm9code/mpu_reset.s
	$(CC) $(ASFLAGS) -Ttext=0 -x assembler-with-cpp -nostartfiles -nostdlib $< -o $@

-include $(DEPENDS)
#---------------------------------------------------------------------------------------
endif
#---------------------------------------------------------------------------------------