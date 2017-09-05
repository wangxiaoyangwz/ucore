#定义变量PROJ为challenge,在后面handin中使用了这个变量，将其插入生成的压缩包名字中。
#可能是用来让同学改为学号等信息对提交的作业进行区分
PROJ    :=challenge
#没有使用的3个变量
EMPTY	:=
SPACE	:= $(EMPTY) $(EMPTY)
SLASH	:= /
 
#变量V=@，后面大量使用了V 
#@的作用是不输出后面的命令，只输出结果  
#在这里修改V即可调整输出的内容  
#也可以 make "V=" 来完整输出
V       := @

# try to infer the correct GCCPREFX
#这里是在选择交叉编译器。
#检查环境变量GCCPREFIX是否被设置
#自行设置GCCPREFIX环境变量 
ifndef GCCPREFIX 
GCCPREFIX := $(shell if i386-elf-objdump -i 2>&1 | grep '^elf32-i386$$' >/dev/null 2>&1; \
	then echo 'i386-elf-'; \
	elif objdump -i 2>&1 | grep 'elf32-i386' >/dev/null 2>&1; \
	then echo ''; \
	else echo "***" 1>&2; \
	echo "*** Error: Couldn't find an i386-elf version of GCC/binutils." 1>&2; \
	echo "*** Is the directory with i386-elf-gcc in your PATH?" 1>&2; \
	echo "*** If your i386-elf toolchain is installed with a command" 1>&2; \
	echo "*** prefix other than 'i386-elf-', set your GCCPREFIX" 1>&2; \
	echo "*** environment variable to that prefix and run 'make' again." 1>&2; \
	echo "*** To turn off this error, run 'gmake GCCPREFIX= ...'." 1>&2; \
	echo "***" 1>&2; exit 1; fi)
endif



# try to infer the correct QEMU
#与上面的类似，这里在设置QEMU。
#QEMU是一款优秀的模拟处理器，使用方便，比virtualbox更适合进行实验
ifndef QEMU
QEMU := $(shell if which qemu-system-i386 > /dev/null; \
	then echo 'qemu-system-i386'; exit; \
	elif which i386-elf-qemu > /dev/null; \
	then echo 'i386-elf-qemu'; exit; \
	else \
	echo "***" 1>&2; \
	echo "*** Error: Couldn't find a working QEMU executable." 1>&2; \
	echo "*** Is the directory containing the qemu binary in your PATH" 1>&2; \
	echo "***" 1>&2; exit 1; fi)
endif

# eliminate default suffix rules
#使用伪目标.SUFFIXES定义自己的后缀列表 
.SUFFIXES: .c .S .h

#遇到error就删除所有目标文件  
# delete target files if there is an error (or make is interrupted)  
.DELETE_ON_ERROR:

# define compiler and flags
#定义编译器和标志#设置编译器选项

# hostcc是给主机用的编译器，按照主机格式。cc是i386,elf32格式的编译器
HOSTCC		:= gcc 
# -g-->为了gdb能够对程序进行调试
#-Wall-->生成警告信息
#-02-->优化处理（0,1,2,3表示不同的优化程度，0为不优化）
HOSTCFLAGS	:= -g -Wall -O2

CC		:= $(GCCPREFIX)gcc

# -fno-builtin 不接受非“__”开头的内建函数  
# -ggdb让gcc 为gdb生成比较丰富的调试信息    
# -m32 编译32位程序    
# -gstabs 此选项以stabs格式声称调试信息,但是不包括gdb调试信息   
# -nostdinc 不在标准系统目录中搜索头文件,只在-I指定的目录中搜索
#DEFS是未定义量。可用来对CFLAGS进行扩展。
CFLAGS	:= -fno-builtin -Wall -ggdb -m32 -gstabs -nostdinc $(DEFS)

#这句话的意思是，如果-fno-stack-protector选项存在，就添加它。过程蛮复杂的。    
# -fstack-protector-all 启用堆栈保护,为所有函数插入保护代码    
# -E 仅作预处理，不进行编译、汇编和链接    
# -x c 指明使用的语言为c语言    
# 前一个/dev/null用来指定目标文件    
# >/dev/null 2>&1 将标准输出与错误输出重定向到/dev/null   
# /dev/null是一个垃圾桶一样的东西   
# ‘&&’之前的半句表示，试着对一个垃圾跑一下这个命令，所有的输出都作为垃圾，为了快一点，开了-E。  
# 如果不能运行，那么&&前面的条件不成立，后面的就被忽视。  
# 如果可以运行，那么&&后面的句子得到执行，于是CFLAGS += -fno-stack-protector
# echo 指令用于字符串的输出
CFLAGS	+= $(shell $(CC) -fno-stack-protector -E -x c /dev/null >/dev/null 2>&1 && echo -fno-stack-protector)

#源文件类型为c和S
CTYPE	:= c S

#一些链接选项 
LD      := $(GCCPREFIX)ld

#ld -V命令会输出连接器的版本与支持的模拟器。在其中搜索elf_i386
#grep指令用于查找内容包含指定的范本样式的文件，显示出来
LDFLAGS	:= -m $(shell $(LD) -V | grep elf_i386 2>/dev/null)

# -nostdlib 不连接系统标准启动文件和标准库文件,只把指定的文件传递给连接器  
LDFLAGS	+= -nostdlib

OBJCOPY := $(GCCPREFIX)objcopy
OBJDUMP := $(GCCPREFIX)objdump

#定义一些命令  
COPY	:= cp
MKDIR   := mkdir -p
MV		:= mv
RM		:= rm -f
AWK		:= awk
SED		:= sed
SH		:= sh
TR		:= tr
TOUCH	:= touch -c

OBJDIR	:= obj
BINDIR	:= bin

ALLOBJS	:=
ALLDEPS	:=
TARGETS	:=

#function.mk中定义了大量的函数
include tools/function.mk


#call函数：call func,变量1，变量2,...  
#listf函数在function.mk中定义，列出某地址（变量1）下某些类型（变量2）文件 
#listf_cc函数即列出某地址（变量1）下.c与.S文件 
listf_cc = $(call listf,$(1),$(CTYPE))

# for hostcc
add_files_host = $(call add_files,$(1),$(HOSTCC),$(HOSTCFLAGS),$(2),$(3))
create_target_host = $(call create_target,$(1),$(2),$(3),$(HOSTCC),$(HOSTCFLAGS))

# for hostcc
# 下面这段与for cc的是一样的功能
add_files_host = $(call add_files,$(1),$(HOSTCC),$(HOSTCFLAGS),$(2),$(3))
create_target_host = $(call create_target,$(1),$(2),$(3),$(HOSTCC),$(HOSTCFLAGS))

#patsubst替换通配符
#cgtype（filenames,type1，type2)-->把文件名中后缀是type1的改为type2，如*.c改为*.o 
cgtype = $(patsubst %.$(2),%.$(3),$(1))

#toobj : get .o obj files: (#files[, packet])
#列出所有.o文件
objfile = $(call toobj,$(1))

#.o-->.asm
asmfile = $(call cgtype,$(call toobj,$(1)),o,asm)

#.o-->.out
outfile = $(call cgtype,$(call toobj,$(1)),o,out)
#.o-->.sym
symfile = $(call cgtype,$(call toobj,$(1)),o,sym)

# for match pattern
match = $(shell echo $(2) | $(AWK) '{for(i=1;i<=NF;i++){if(match("$(1)","^"$$(i)"$$")){exit 1;}}}'; echo $$?)


# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
# include kernel/user

INCLUDE	+= libs/

CFLAGS	+= $(addprefix -I,$(INCLUDE))

LIBDIR	+= libs
#生成这些.o文件--obj/kern/*/*.o 的相关makefile代码为
$(call add_files_cc,$(call listf_cc,$(LIBDIR)),libs,)

# -------------------------------------------------------------------
# kernel

KINCLUDE	+= kern/debug/ \
			   kern/driver/ \
			   kern/trap/ \
			   kern/mm/

KSRCDIR		+= kern/init \
			   kern/libs \
			   kern/debug \
			   kern/driver \
			   kern/trap \
			   kern/mm

KCFLAGS		+= $(addprefix -I,$(KINCLUDE))

$(call add_files_cc,$(call listf_cc,$(KSRCDIR)),kernel,$(KCFLAGS))

KOBJS	= $(call read_packet,kernel libs)

# create kernel target
kernel = $(call totarget,kernel)

$(kernel): tools/kernel.ld

$(kernel): $(KOBJS)
	@echo + ld $@
	$(V)$(LD) $(LDFLAGS) -T tools/kernel.ld -o $@ $(KOBJS)
	@$(OBJDUMP) -S $@ > $(call asmfile,kernel)
	@$(OBJDUMP) -t $@ | $(SED) '1,/SYMBOL TABLE/d; s/ .* / /; /^$$/d' > $(call symfile,kernel)

$(call create_target,kernel)

# -------------------------------------------------------------------

# create bootblock
#bootasm.o,bootmain.o的相关makefile代码
bootfiles = $(call listf_cc,boot)
$(foreach f,$(bootfiles),$(call cc_compile,$(f),$(CC),$(CFLAGS) -Os -nostdinc))

bootblock = $(call totarget,bootblock)
#需要这些代码告诉make应该怎么去编译链接BootLoader程序
$(bootblock): $(call toobj,$(bootfiles)) | $(call totarget,sign)
	@echo + ld $@
	$(V)$(LD) $(LDFLAGS) -N -e start -Ttext 0x7C00 $^ -o $(call toobj,bootblock)
	@$(OBJDUMP) -S $(call objfile,bootblock) > $(call asmfile,bootblock)
	@$(OBJDUMP) -t $(call objfile,bootblock) | $(SED) '1,/SYMBOL TABLE/d; s/ .* / /; /^$$/d' > $(call symfile,bootblock)
	@$(OBJCOPY) -S -O binary $(call objfile,bootblock) $(call outfile,bootblock)
	@$(call totarget,sign) $(call outfile,bootblock) $(bootblock)

$(call create_target,bootblock)

# -------------------------------------------------------------------

#生成sign工具的makefile代码为
# create 'sign' tools---
$(call add_files_host,tools/sign.c,sign,sign)
$(call create_target_host,sign,sign)

# -------------------------------------------------------------------

# create ucore.img--
#生成ucore.img--需要这些代码告诉make应该怎么去编译链接ucore程序
UCOREIMG	:= $(call totarget,ucore.img)

$(UCOREIMG): $(kernel) $(bootblock)
	$(V)dd if=/dev/zero of=$@ count=10000
	$(V)dd if=$(bootblock) of=$@ conv=notrunc
	$(V)dd if=$(kernel) of=$@ seek=1 conv=notrunc

$(call create_target,ucore.img)

# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

$(call finish_all)

IGNORE_ALLDEPS	= clean \
				  dist-clean \
				  grade \
				  touch \
				  print-.+ \
				  handin

ifeq ($(call match,$(MAKECMDGOALS),$(IGNORE_ALLDEPS)),0)
-include $(ALLDEPS)
endif

# files for grade script
#脚本文件
TARGETS: $(TARGETS)
all: $(TARGETS)
.DEFAULT_GOAL := TARGETS

.PHONY: qemu qemu-nox debug debug-nox
lab1-mon: $(UCOREIMG)
	$(V)$(TERMINAL) -e "$(QEMU) -S -s -d in_asm -D $(BINDIR)/q.log -monitor stdio -hda $< -serial null"
	$(V)sleep 2
	$(V)$(TERMINAL) -e "gdb -q -x tools/lab1init"
debug-mon: $(UCOREIMG)
#	$(V)$(QEMU) -S -s -monitor stdio -hda $< -serial null &
	$(V)$(TERMINAL) -e "$(QEMU) -S -s -monitor stdio -hda $< -serial null"
	$(V)sleep 2
	$(V)$(TERMINAL) -e "gdb -q -x tools/moninit"

#终端模式打开qemu 
qemu-mon: $(UCOREIMG)
	$(V)$(QEMU) -monitor stdio -hda $< -serial null

#新窗口下打开qemu 
qemu: $(UCOREIMG)
	$(V)$(QEMU) -parallel stdio -hda $< -serial null

qemu-nox: $(UCOREIMG)
	$(V)$(QEMU) -serial mon:stdio -hda $< -nographic
TERMINAL        :=gnome-terminal
gdb: $(UCOREIMG)
	$(V)$(QEMU) -S -s -parallel stdio -hda $< -serial null

#调试
debug: $(UCOREIMG)
	$(V)$(QEMU) -S -s -parallel stdio -hda $< -serial null &
	$(V)sleep 2
	$(V)$(TERMINAL)  -e "cgdb -q -x tools/gdbinit"

#在终端打开qemu进行调试，现在终端会陷入死循环QAQ  	
debug-nox: $(UCOREIMG)
	$(V)$(QEMU) -S -s -serial mon:stdio -hda $< -nographic &
	$(V)sleep 2
	$(V)$(TERMINAL) -e "gdb -q -x tools/gdbinit"

.PHONY: clean dist-clean handin packall

#删除
clean:
	$(V)$(RM) $(GRADE_GDB_IN) $(GRADE_QEMU_OUT)
	-$(RM) -r $(OBJDIR) $(BINDIR)

#压缩包也删除
dist-clean: clean
	-$(RM) $(HANDIN)
#打包并输出一句话
handin: packall
	@echo Please visit http://learn.tsinghua.edu.cn and upload $(HANDIN). Thanks!
#打包
packall: clean
	@$(RM) -f $(HANDIN)
	@tar -czf $(HANDIN) `find . -type f -o -type d | grep -v '^\.*$$' | grep -vF '$(HANDIN)'`
