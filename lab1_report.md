生成ucore.img
$(UCOREIMG): $(kernel) $(bootblock)
	$(V)dd if=/dev/zero of=$@ count=10000
	$(V)dd if=$(bootblock) of=$@ conv=notrunc
	$(V)dd if=$(kernel) of=$@ seek=1 conv=notrunc

为了生成ucore.img，首先需要生成bootblock、kernel
	生成bootloaer相关代码
	$(bootblock): $(call toobj,$(bootfiles)) | $(call totarget,sign)
		@echo + ld $@
		$(V)$(LD) $(LDFLAGS) -N -e start -Ttext 0x7C00 $^ -o $(call toobj,bootblock)
		@$(OBJDUMP) -S $(call objfile,bootblock) > $(call asmfile,bootblock)
		@$(OBJDUMP) -t $(call objfile,bootblock) | $(SED) '1,/SYMBOL TABLE/d; s/ .* / /; /^$$/d' > $(call symfile,bootblock)
		@$(OBJCOPY) -S -O binary $(call objfile,bootblock) $(call outfile,bootblock)
		@$(call totarget,sign) $(call outfile,bootblock) $(bootblock)

		为了生成BootLoader---为了生成bootblock，首先需要生成bootasm.o、bootmain.o、sign
			生成bootasm.o,bootmain.o的相关makefile代码为
			bootfiles = $(call listf_cc,boot)
			$(foreach f,$(bootfiles),$(call cc_compile,$(f),$(CC),$(CFLAGS) -Os -nostdinc))

			为了生成bootasm.o需要bootasm.S
||	|		实际命令为
|	|	| gcc -Iboot/ -fno-builtin -Wall -ggdb -m32 -gstabs \
|	|	| 	-nostdinc  -fno-stack-protector -Ilibs/ -Os -nostdinc \
|	|	| 	-c boot/bootasm.S -o obj/boot/bootasm.o
|	|	| 其中关键的参数为
|	|	| 	-ggdb  生成可供gdb使用的调试信息。这样才能用qemu+gdb来调试bootloader or ucore。
|	|	|	-m32  生成适用于32位环境的代码。我们用的模拟硬件是32bit的80386，所以ucore也要是32位的软件。
|	|	| 	-gstabs  生成stabs格式的调试信息。这样要ucore的monitor可以显示出便于开发者阅读的函数调用栈信息
|	|	| 	-nostdinc  不使用标准库。标准库是给应用程序用的，我们是编译ucore内核，OS内核是提供服务的，所以所有的服务要自给自足。
|	|	|	-fno-stack-protector  不生成用于检测缓冲区溢出的代码。这是for 应用程序的，我们是编译内核，ucore内核好像还用不到此功能。
|	|	| 	-Os  为减小代码大小而进行优化。根据硬件spec，主引导扇区只有512字节，我们写的简单bootloader的最终大小不能大于510字节。
|	|	| 	-I<dir>  添加搜索头文件的路径
|	|	| 生成bootmain.o需要bootmain.c
|	|	| 实际命令为
|	|	| gcc -Iboot/ -fno-builtin -Wall -ggdb -m32 -gstabs -nostdinc \
|	|	| 	-fno-stack-protector -Ilibs/ -Os -nostdinc \
|	|	| 	-c boot/bootmain.c -o obj/boot/bootmain.o
|	|	| 新出现的关键参数有
|	|	| 	-fno-builtin  除非用__builtin_前缀，
|	|	|	              否则不进行builtin函数的优化
|	|>	bin/sign
|	|	| 生成sign工具的makefile代码为
|	|	| $(call add_files_host,tools/sign.c,sign,sign)
|	|	| $(call create_target_host,sign,sign)
|	|	| 实际命令为
|	|	| gcc -Itools/ -g -Wall -O2 -c tools/sign.c \
|	|	| 	-o obj/sign/tools/sign.o
|	|	| gcc -g -Wall -O2 obj/sign/tools/sign.o -o bin/sign

|	| 首先生成bootblock.o
|	| ld -m    elf_i386 -nostdlib -N -e start -Ttext 0x7C00 \
|	|	obj/boot/bootasm.o obj/boot/bootmain.o -o obj/bootblock.o
|	| 其中关键的参数为
|	|	-m <emulation>  模拟为i386上的连接器
|	|	-nostdlib  不使用标准库
|	|	-N  设置代码段和数据段均可读写
|	|	-e <entry>  指定入口
|	|	-Ttext  制定代码段开始位置

|	| 拷贝二进制代码bootblock.o到bootblock.out
|	| objcopy -S -O binary obj/bootblock.o obj/bootblock.out
|	| 其中关键的参数为
|	|	-S  移除所有符号和重定位信息
|	|	-O <bfdname>  指定输出格式

|	| 使用sign工具处理bootblock.out，生成bootblock
|	| bin/sign obj/bootblock.out bin/bootblock

|>	bin/kernel
|	| 生成kernel的相关代码为
		$(kernel): tools/kernel.ld

	    $(kernel): $(KOBJS)
		@echo + ld $@
		$(V)$(LD) $(LDFLAGS) -T tools/kernel.ld -o $@ $(KOBJS)
		@$(OBJDUMP) -S $@ > $(call asmfile,kernel)
		@$(OBJDUMP) -t $@ | $(SED) '1,/SYMBOL TABLE/d; s/ .* / /; /^$$/d' > $(call symfile,kernel)
|	| 为了生成kernel，首先需要 kernel.ld init.o readline.o stdio.o kdebug.o
|	|	kmonitor.o panic.o clock.o console.o intr.o picirq.o trap.o
|	|	trapentry.o vectors.o pmm.o  printfmt.o string.o
|	| kernel.ld已存在

|	|>	obj/kern/*/*.o 
|	|	| 生成这些.o文件的相关makefile代码为
|	|>	obj/kern/init/init.o
|	|	| 编译需要init.c
|	|	| 实际命令为
|	|	|	gcc -Ikern/init/ -fno-builtin -Wall -ggdb -m32 \
|	|	|		-gstabs -nostdinc  -fno-stack-protector \
|	|	|		-Ilibs/ -Ikern/debug/ -Ikern/driver/ \
|	|	|		-Ikern/trap/ -Ikern/mm/ -c kern/init/init.c \
|	|	|		-o obj/kern/init/init.o
|	| 生成kernel时，makefile的几条指令中有@前缀的都不必需
|	| 必需的命令只有
|	| ld -m    elf_i386 -nostdlib -T tools/kernel.ld -o bin/kernel \
|	| 	obj/kern/init/init.o obj/kern/libs/readline.o \
|	| 	obj/kern/libs/stdio.o obj/kern/debug/kdebug.o \
|	| 	obj/kern/debug/kmonitor.o obj/kern/debug/panic.o \
|	| 	obj/kern/driver/clock.o obj/kern/driver/console.o \
|	| 	obj/kern/driver/intr.o obj/kern/driver/picirq.o \
|	| 	obj/kern/trap/trap.o obj/kern/trap/trapentry.o \
|	| 	obj/kern/trap/vectors.o obj/kern/mm/pmm.o \
|	| 	obj/libs/printfmt.o obj/libs/string.o
|	| 其中新出现的关键参数为
|	|	-T <scriptfile>  让连接器使用指定的脚本

| 生成一个有10000个块的文件，每个块默认512字节，用0填充
| dd if=/dev/zero of=bin/ucore.img count=10000
|
| 把bootblock中的内容写到第一个块
| dd if=bin/bootblock of=bin/ucore.img conv=notrunc
|
| 从第二个块开始写kernel中的内容
| dd if=bin/kernel of=bin/ucore.img seek=1 conv=notrunc


//////////////////////////////////////////////////////////////////////////////////////////////////////////////


为了生成ucore.img，首先需要生成bootblock、kernel
	生成bootblock的相关代码为


>bin/bootblock
为了生成bootblock，首先需要生成bootasm.o、bootmain.o、sign
	生成bootasm.o,bootmain.o的相关makefile代码为---obj/boot/bootasm.o, obj/boot/bootmain.o

!!!!先使用gcc命令，把./kern目录下的代码都编译成obj/kern/*/*.o文件；
为了生成--obj---bootasm.o需要bootasm.S----->编译bootasm.c
|	|	| gcc -Iboot/ -fno-builtin -Wall -ggdb -m32 -gstabs \
|	|	| 	-nostdinc  -fno-stack-protector -Ilibs/ -Os -nostdinc \
|	|	| 	-c boot/bootasm.S -o obj/boot/bootasm.o
			关键的参数

!!!!用gcc命令，把boot目录下的文件编译成obj/boot/*.o文件；
生成--obj--bootmain.o需要bootmain.c----->编译bootmain.c
|	|	| gcc -Iboot/ -fno-builtin -Wall -ggdb -m32 -gstabs -nostdinc \
|	|	| 	-fno-stack-protector -Ilibs/ -Os -nostdinc \
|	|	| 	-c boot/bootmain.c -o obj/boot/bootmain.o

!!!!!用gcc把tools/sign.c编译成obj/sign/tools/sign.o；
bin/sign
生成sign工具
|	|	| gcc -Itools/ -g -Wall -O2 -c tools/sign.c \
|	|	| 	-o obj/sign/tools/sign.o
|	|	| gcc -g -Wall -O2 obj/sign/tools/sign.o -o bin/sign


!!!!用ld把obj/boot/*.o连接成obj/bootblock.o；
使用生成的obj/sign/tools/sign.o，将obj/bootblock.o文件规范化为，符合规范的硬盘住引导扇区的文件bin/bootblock
生成bootblock.o
|	| ld -m    elf_i386 -nostdlib -N -e start -Ttext 0x7C00 \
|	|	obj/boot/bootasm.o obj/boot/bootmain.o -o obj/bootblock.o


拷贝二进制代码bootblock.o到bootblock.out
|	| objcopy -S -O binary obj/bootblock.o obj/bootblock.out

使用sign工具处理bootblock.out，生成bootblock
|	| bin/sign obj/bootblock.out bin/bootblock

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////

先使用gcc命令，把./kern目录下的代码都编译成obj/kern/*/*.o文件；
用ld命令通过/tools/kern.ls文件配置，把obj/kern/*/*.o文件连接成bin/kern；
用gcc命令，把boot目录下的文件编译成obj/boot/*.o文件；
用gcc把tools/sign.c编译成obj/sign/tools/sign.o；
用ld把obj/boot/*.o连接成obj/bootblock.o；
使用第4步生成的obj/sign/tools/sign.o，将obj/bootblock.o文件规范化为，符合规范的硬盘住引导扇区的文件bin/bootblock
用dd命令创建了一个bin/ucore.img文件；
用dd命令把bin/bootblock写入bin/ucore.img文件；
用dd命令创bin/kernel写入bin/ucore.img文件。


//////////////////////////////////////////////////////////////////////////////////////////////////////////////

//Part1:生成bin/kernel--用ld命令通过/tools/kern.ls文件配置，把obj/kern/*/*.o文件连接成bin/kern；
//1、gcc命令，把./kern目录下的代码都编译成obj/kern/*/*.o文件；
//生成init.o
+ cc kern/init/init.c
gcc -Ikern/init/ -fno-builtin  -ggdb -m32 -gstabs -nostdinc  -fno-stack-protector -Ilibs/ -Ikern/debug/ -Ikern/driver/ -Ikern/trap/ -Ikern/mm/ -c kern/init/init.c -o obj/kern/init/init.o

//生成stdio.o
+ cc kern/libs/stdio.c
gcc -Ikern/libs/ -fno-builtin  -ggdb -m32 -gstabs -nostdinc  -fno-stack-protector -Ilibs/ -Ikern/debug/ -Ikern/driver/ -Ikern/trap/ -Ikern/mm/ -c kern/libs/stdio.c -o obj/kern/libs/stdio.o

//生成readline.o
+ cc kern/libs/readline.c
gcc -Ikern/libs/ -fno-builtin  -ggdb -m32 -gstabs -nostdinc  -fno-stack-protector -Ilibs/ -Ikern/debug/ -Ikern/driver/ -Ikern/trap/ -Ikern/mm/ -c kern/libs/readline.c -o obj/kern/libs/readline.o

//生成panic.o
+ cc kern/debug/panic.c
gcc -Ikern/debug/ -fno-builtin  -ggdb -m32 -gstabs -nostdinc  -fno-stack-protector -Ilibs/ -Ikern/debug/ -Ikern/driver/ -Ikern/trap/ -Ikern/mm/ -c kern/debug/panic.c -o obj/kern/debug/panic.o

//生成kdebug.o
+ cc kern/debug/kdebug.c
gcc -Ikern/debug/ -fno-builtin  -ggdb -m32 -gstabs -nostdinc  -fno-stack-protector -Ilibs/ -Ikern/debug/ -Ikern/driver/ -Ikern/trap/ -Ikern/mm/ -c kern/debug/kdebug.c -o obj/kern/debug/kdebug.o

//生成kmonitor.o
+ cc kern/debug/kmonitor.c
gcc -Ikern/debug/ -fno-builtin  -ggdb -m32 -gstabs -nostdinc  -fno-stack-protector -Ilibs/ -Ikern/debug/ -Ikern/driver/ -Ikern/trap/ -Ikern/mm/ -c kern/debug/kmonitor.c -o obj/kern/debug/kmonitor.o

//生成clock.o
+ cc kern/driver/clock.c
gcc -Ikern/driver/ -fno-builtin  -ggdb -m32 -gstabs -nostdinc  -fno-stack-protector -Ilibs/ -Ikern/debug/ -Ikern/driver/ -Ikern/trap/ -Ikern/mm/ -c kern/driver/clock.c -o obj/kern/driver/clock.o

//生成console.o
+ cc kern/driver/console.c
gcc -Ikern/driver/ -fno-builtin  -ggdb -m32 -gstabs -nostdinc  -fno-stack-protector -Ilibs/ -Ikern/debug/ -Ikern/driver/ -Ikern/trap/ -Ikern/mm/ -c kern/driver/console.c -o obj/kern/driver/console.o

//生成picirq.o
+ cc kern/driver/picirq.c
gcc -Ikern/driver/ -fno-builtin  -ggdb -m32 -gstabs -nostdinc  -fno-stack-protector -Ilibs/ -Ikern/debug/ -Ikern/driver/ -Ikern/trap/ -Ikern/mm/ -c kern/driver/picirq.c -o obj/kern/driver/picirq.o

//生成intr.o
+ cc kern/driver/intr.c
gcc -Ikern/driver/ -fno-builtin  -ggdb -m32 -gstabs -nostdinc  -fno-stack-protector -Ilibs/ -Ikern/debug/ -Ikern/driver/ -Ikern/trap/ -Ikern/mm/ -c kern/driver/intr.c -o obj/kern/driver/intr.o

//生成trap.o
+ cc kern/trap/trap.c
gcc -Ikern/trap/ -fno-builtin  -ggdb -m32 -gstabs -nostdinc  -fno-stack-protector -Ilibs/ -Ikern/debug/ -Ikern/driver/ -Ikern/trap/ -Ikern/mm/ -c kern/trap/trap.c -o obj/kern/trap/trap.o

//生成vectors.o
+ cc kern/trap/vectors.S
gcc -Ikern/trap/ -fno-builtin  -ggdb -m32 -gstabs -nostdinc  -fno-stack-protector -Ilibs/ -Ikern/debug/ -Ikern/driver/ -Ikern/trap/ -Ikern/mm/ -c kern/trap/vectors.S -o obj/kern/trap/vectors.o

//生成trapentry.o
+ cc kern/trap/trapentry.S
gcc -Ikern/trap/ -fno-builtin  -ggdb -m32 -gstabs -nostdinc  -fno-stack-protector -Ilibs/ -Ikern/debug/ -Ikern/driver/ -Ikern/trap/ -Ikern/mm/ -c kern/trap/trapentry.S -o obj/kern/trap/trapentry.o

//生成pmm.o
+ cc kern/mm/pmm.c
gcc -Ikern/mm/ -fno-builtin  -ggdb -m32 -gstabs -nostdinc  -fno-stack-protector -Ilibs/ -Ikern/debug/ -Ikern/driver/ -Ikern/trap/ -Ikern/mm/ -c kern/mm/pmm.c -o obj/kern/mm/pmm.o


//生成string.o
+ cc libs/string.c
gcc -Ilibs/ -fno-builtin  -ggdb -m32 -gstabs -nostdinc  -fno-stack-protector -Ilibs/  -c libs/string.c -o obj/libs/string.o

//生成printfmt.o
+ cc libs/printfmt.c
gcc -Ilibs/ -fno-builtin  -ggdb -m32 -gstabs -nostdinc  -fno-stack-protector -Ilibs/  -c libs/printfmt.c -o obj/libs/printfmt.o

//2、用ld命令通过/tools/kern.ls文件配置，把obj/kern/*/*.o文件连接成bin/kern
//连接.o文件生成bin/kernel
+ ld bin/kernel
ld -m    elf_i386 -nostdlib -T tools/kernel.ld -o bin/kernel  obj/kern/init/init.o obj/kern/libs/stdio.o obj/kern/libs/readline.o obj/kern/debug/panic.o obj/kern/debug/kdebug.o obj/kern/debug/kmonitor.o obj/kern/driver/clock.o obj/kern/driver/console.o obj/kern/driver/picirq.o obj/kern/driver/intr.o obj/kern/trap/trap.o obj/kern/trap/vectors.o obj/kern/trap/trapentry.o obj/kern/mm/pmm.o  obj/libs/string.o obj/libs/printfmt.o
 
//Part2:生成bin/bootblock---用ld把obj/boot/*.o连接成obj/bootblock.o
//3、用gcc命令，把boot目录下的文件编译成obj/boot/*.o文件
//生成bootasm.o
+ cc boot/bootasm.S
gcc -Iboot/ -fno-builtin  -ggdb -m32 -gstabs -nostdinc  -fno-stack-protector -Ilibs/ -Os -nostdinc -c boot/bootasm.S -o obj/boot/bootasm.o
//生成bootmain.o
+ cc boot/bootmain.c
gcc -Iboot/ -fno-builtin  -ggdb -m32 -gstabs -nostdinc  -fno-stack-protector -Ilibs/ -Os -nostdinc -c boot/bootmain.c -o obj/boot/bootmain.o
 
//Part3:生成bin/sign
//4、用gcc把tools/sign.c编译成obj/sign/tools/sign.o；
+ cc tools/sign.c
gcc -Itools/ -g  -O2 -c tools/sign.c -o obj/sign/tools/sign.o
gcc -g  -O2 obj/sign/tools/sign.o -o bin/sign
 
//连接,生成bootblock
//使用第4步生成的obj/sign/tools/sign.o，将obj/bootblock.o文件规范化为，符合规范的硬盘住引导扇区的文件bin/bootblock
+ ld bin/bootblock
ld -m    elf_i386 -nostdlib -N -e start -Ttext 0x7C00 obj/boot/bootasm.o obj/boot/bootmain.o -o obj/bootblock.o
'obj/bootblock.out' size: 468 bytes
build 512 bytes boot sector: 'bin/bootblock' success!

//Part4:生成ucore.img
//用dd命令创建了一个bin/ucore.img文件
dd if=/dev/zero of=bin/ucore.img count=10000//生成一个有10000个块的文件，每个块默认512字节，用0填充
记录了10000+0 的读入
记录了10000+0 的写出
5120000字节(5.1 MB)已复制，0.219116 秒，23.4 MB/秒

dd if=bin/bootblock of=bin/ucore.img conv=notrunc//用dd命令把bin/bootblock写入bin/ucore.img文件；
记录了1+0 的读入
记录了1+0 的写出
512字节(512 B)已复制，0.000170474 秒，3.0 MB/秒

dd if=bin/kernel of=bin/ucore.img seek=1 conv=notrunc//用dd命令创bin/kernel写入bin/ucore.img文件。
记录了138+1 的读入
记录了138+1 的写出
70824字节(71 kB)已复制，0.00297832 秒，23.8 MB/秒
 
一些出现的参数
 
GCCFLAGS
# -g 是为了gdb能够对程序进行调试
# -Wall 生成警告信息
# -O2 优化处理（0,1,2,3表示不同的优化程度，0为不优化）
# -fno-builtin 不接受非“__”开头的内建函数
# -ggdb让gcc 为gdb生成比较丰富的调试信息
# -m32 编译32位程序
# -gstabs 此选项以stabs格式声称调试信息,但是不包括gdb调试信息
# -nostdinc 不在标准系统目录中搜索头文件,只在-I指定的目录中搜索
# -fstack-protector-all 启用堆栈保护,为所有函数插入保护代码
# -E 仅作预处理，不进行编译、汇编和链接
# -x c 指明使用的语言为C语言
 
LDFLAGS
# -nostdlib 不连接系统标准启动文件和标准库文件,只把指定的文件传递给连接器
#-m elf_i386使用elf_i386模拟器
#-N把 text 和 data 节设置为可读写.同时,取消数据节的页对齐,同时,取消对共享库的连接.
#-e func以符号func的位置作为程序开始运行的位置
#-Ttext addr指定节在文件中的绝对地址为addr



















