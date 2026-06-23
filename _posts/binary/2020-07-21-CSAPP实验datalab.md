---
math: true
title: CSAPP实验datalab
tags:
  - binary
---
## 获取实验并使用

从[http://csapp.cs.cmu.edu/3e/labs.html](http://csapp.cs.cmu.edu/3e/labs.html)获取。获取方法是`点击实验后面的Self-Study Handout`。

获取后解压，解压命令：

```sh
$ tar -xvf datalab-handout.tar
```

题目描述在`bits.c`中。实验目的是按要求完成`bits.c`中的所有函数。实验完毕之后开始测试。测试方法是，使用`dlc`进行预检测，使用`make btest`进行编译。之后运行`./btest`。

你可以使用参数`-h`来获得帮助。

```sh
$ btest -h
Usage: ./btest [-hg] [-r <n>] [-f <name> [-1|-2|-3 <val>]*] [-T <time limit>]
  -1 <val>  Specify first function argument
  -2 <val>  Specify second function argument
  -3 <val>  Specify third function argument
  -f <name> Test only the named function
  -g        Compact output for grading (with no error msgs)
  -h        Print this message
  -r <n>    Give uniform weight of n for all problems
  -T <lim>  Set timeout limit to lim
```

本实验是默认在32位机上进行测试。

## 实验分析

### bitXor

#### 描述

> */** 
>
>  ** bitXor - x^y using only ~ and &* 
>
>  **  Example: bitXor(4, 5) = 1*
>
>  **  Legal ops: ~ &*
>
>  **  Max ops: 14*
>
>  **  Rating: 1*
>
>  **/*

用`~`和`&`实现按位异或。

#### 思路

本来的思路是运用德摩根定理一把梭，结果发现这个跟逻辑上的不太一样。改了思路，运用`x^y=(x&~y)|(~x&y)`

#### 代码

```c
int bitXor(int x, int y) {
  // return ~((~x)&(~y)); 原思路
  return ~(~(~x&y)&~(x&~y));
}
```

### tmin

#### 描述

> /*
>
>  ** tmin - return minimum two's complement integer* 
>
>  **  Legal ops: ! ~ & ^ \| + << >>*
>
>  **  Max ops: 4*
>
>  **  Rating: 1*
>
>  **/*

返回一个TMin。

#### 思路

TMin的二进制为`10000000000000000000000000000000`。只要拿一个1左移31位就好了。

#### 代码

```c
int tmin(void) {
  return (1 << 31);
}
```

### isTmax

#### 描述

> /*
>
>  ** isTmax - returns 1 if x is the maximum, two's complement number,*
>
>  **   and 0 otherwise* 
>
>  **  Legal ops: ! ~ & ^ \| +*
>
>  **  Max ops: 10*
>
>  **  Rating: 1*
>
>  **/*

判断一个数是不是TMax。

#### 思路

TMax的一个特性：TMax加一再取反是TMax。利用这个特性和自己异或得到0。注意0xffffffff也有本特性，但是0xffffffff+1是0。

#### 代码

```c
int isTmax(int x) {
  return !(~(x+1)^x)&(!!(x+1));
}
```

### allOddBits

#### 描述

> /*
>
>  ** allOddBits - return 1 if all odd-numbered bits in word set to 1*
>
>  **  where bits are numbered from 0 (least significant) to 31 (most significant)*
>
>  **  Examples allOddBits(0xFFFFFFFD) = 0, allOddBits(0xAAAAAAAA) = 1*
>
>  **  Legal ops: ! ~ & ^ \| + << >>*
>
>  **  Max ops: 12*
>
>  **  Rating: 2*
>
>  **/*

默认最右边那一位为第0位，然后最左边那个依次推过来是31位。判断此数是不是所有的奇数位都是1。

#### 思路

如果满足条件的话，把偶数位置为0之后和自身异或得到的应该是0。

#### 代码

```c
int allOddBits(int x) {
  int a = 170 + (170 << 8) + (170 << 16) + (170 << 24); 
  //10101010101010101010101010101010
  return !((x&a)^a);
}
```

### negate

#### 描述

> /*
>
>  ** negate - return -x* 
>
>  **  Example: negate(1) = -1.*
>
>  **  Legal ops: ! ~ & ^ \| + << >>*
>
>  **  Max ops: 5*
>
>  **  Rating: 2*
>
>  **/*

搞个负数出来。

#### 思路

取反加一。

#### 代码

```c
int negate(int x) {
  return (~x+1);
}
```

### isAsciiDigit

#### 描述

> /*
>
>  ** isAsciiDigit - return 1 if 0x30 <= x <= 0x39 (ASCII codes for characters '0' to '9')*
>
>  **  Example: isAsciiDigit(0x35) = 1.*
>
>  **      isAsciiDigit(0x3a) = 0.*
>
>  **      isAsciiDigit(0x05) = 0.*
>
>  **  Legal ops: ! ~ & ^ \| + << >>*
>
>  **  Max ops: 15*
>
>  **  Rating: 3*
>
>  **/*

判断一个数字是否在0x30到0x39范围之内。

#### 思路

原思路想判断<=0，后来发现不会。

做减法，看是否大于等于0。判断是否大于等于0`x - y >= 0`的方法是取符号位且取逻辑反`!(x+(~y+1)>>31)`。

#### 代码

```c
int isAsciiDigit(int x) {
  /* 原思路
  int a = x+(~0x30+1)>>31;
  int b = x+(~0x39+1)>>31;
  return ~a & b;
  */
  int a = x+(~0x30+1)>>31;
  int b = 0x39+(~x+1)>>31;
  return !a & !b;
}
```

### conditional

#### 描述

> /*
>
>  ** conditional - same as x ? y : z* 
>
>  **  Example: conditional(2,4,5) = 4*
>
>  **  Legal ops: ! ~ & ^ \| + << >>*
>
>  **  Max ops: 16*
>
>  **  Rating: 3*
>
>  **/*

实现一个三目运算符`x ? y : z`。

#### 思路

用`!`判断x的真假，然后用一个特性返回数字：一个数和0相与结果为0，和**0xffffffff**相与结果为本身。

#### 代码

```c
int conditional(int x, int y, int z) {
  return ((!x+(~0))&y) | ((!!x+(~0))&z);
  // !x/!!x 加一，要么等于0，要么等于0xffffffff。  
}
```

### isLessOrEqual

#### 描述

> /*
>
>  ** isLessOrEqual - if x <= y then return 1, else return 0* 
>
>  **  Example: isLessOrEqual(4,5) = 1.*
>
>  *  Legal ops: ! ~ & ^ \| + << >>
>
>  **  Max ops: 24*
>
>  **  Rating: 3*
>
>  **/*

如果`x<=y`则返回1，否则返回0。

#### 思路

取符号位判断符号，x正y负直接返回0，x负y正直接返回1，其他的做减法判断。

#### 代码

```c
int isLessOrEqual(int x, int y) {
  int a = x >> 31;
  int b = y >> 31;
  return !(!a&b) & ((a&!b) | !((y + (~x+1))&(1<<31)));
}
```

### logicalNeg

#### 描述

> /*
>
>  ** logicalNeg - implement the ! operator, using all of* 
>
>  **       the legal operators except !*
>
>  **  Examples: logicalNeg(3) = 0, logicalNeg(0) = 1*
>
>  **  Legal ops: ~ & ^ \| + << >>*
>
>  **  Max ops: 12*
>
>  **  Rating: 4* 
>
>  **/*

用其他的运算符实现逻辑符`!`

#### 思路

0的补码还是0。TMin的补码是TMin。其他数补码符号位相反。根据真值表得出答案。

#### 代码

```c
int logicalNeg(int x) {
  return ((~(~x+1)&~x)>>31)&1;
}
```

### howManyBits

#### 描述

> /*
>
>   *  *howManyBits - return the minimum number of bits required to represent x in*
>
>  **       two's complement*
>
>  ** Examples: howManyBits(12) = 5*
>
>  **      howManyBits(298) = 10*
>
>  **      howManyBits(-5) = 4*
>
>  **      howManyBits(0) = 1*
>
>  **      howManyBits(-1) = 1*
>
>  **      howManyBits(0x80000000) = 32*
>
>  ** Legal ops: ! ~ & ^ \| + << >>*
>
>  ** Max ops: 90*
>
>  ** Rating: 4*
>
>  **/*

给一个数字x,求出要表示出x需要的最少的位数。

#### 思路

$$
令二进制数B = b_{31}b_{30}...b_{2}b_{1}b_{0} \\

若能用x位补码表示，则b_{x}=b_{x+1}=...=b_{31}\not=b_{x-1} \\

若30\ge y\ge x,b_{y}\oplus b_{y+1}=0,b_{x} \oplus b_{x-1}=1
$$

只需要异或x+1，二分法找出最高位在哪一位即可。

#### 代码

```c
int howManyBits(int x) {
  int n=0;
  x = x ^ (x << 1);
  n += ((!!(x&((~0)<<(n+16))))<<4);
  n += ((!!(x&((~0)<<(n+8))))<<3);
  n += ((!!(x&((~0)<<(n+4))))<<2);
  n += ((!!(x&((~0)<<(n+2))))<<1);
  n += (!!(x&((~0)<<(n+1))));
  return n+1;
}
```

### floatScale2

#### 描述

> /*
>
>  ** floatScale2 - Return bit-level equivalent of expression 2\*f for*
>
>  **  floating point argument f.*
>
>  **  Both the argument and result are passed as unsigned int's, but*
>
>  **  they are to be interpreted as the bit-level representation of*
>
>  **  single-precision floating point values.*
>
>  **  When argument is NaN, return argument*
>
>  **  Legal ops: Any integer/unsigned operations incl. ||, &&. also if, while*
>
>  **  Max ops: 30*
>
>  **  Rating: 4*
>
>  **/*

给出一个无符号整数x，将其看作一个浮点数，返回此数的两倍`x*2`。

#### 思路

取出s、exp和frac，按照浮点数模式模拟即可。

如果exp为0，则是非规格，直接左移即可。

如果exp不是0xff，即有效，则直接在指数上操作，直接exp++。

#### 代码

```c
unsigned floatScale2(unsigned uf) {
  unsigned frac = uf & 0x007fffff;
  unsigned exp = (uf>>23) & 0xff;
  unsigned s = uf>>31;
  if (!exp){
    frac <<= 1;
    if (frac >>23){
      frac = frac & 0x007fffff;
      exp++;
    }
  }
  else if (exp != 0xff) 
  {
    exp++;
  }
  
  return (s<<31)|(exp<<23)|frac;
}
```

### floatFloat2Int

#### 描述

> /*
>
>  ** floatFloat2Int - Return bit-level equivalent of expression (int) f*
>
>  **  for floating point argument f.*
>
>  **  Argument is passed as unsigned int, but*
>
>  **  it is to be interpreted as the bit-level representation of a*
>
>  **  single-precision floating point value.*
>
>  **  Anything out of range (including NaN and infinity) should return*
>
>  **  0x80000000u.*
>
>  **  Legal ops: Any integer/unsigned operations incl. \|\|, &&. also if, while*
>
>  **  Max ops: 30*
>
>  **  Rating: 4*
>
>  **/*

给出一个无符号整数x，将其看作一个浮点数，实现一个`(int)x`的功能。

#### 思路

这题改了好久好久。主要是思考上下界溢出的问题。

下界溢出的临界是`bin(x) = 0 01111111 00000000000000000000000`，此时s=0，exp=127，frac=0。表示的数字刚好是1.0。小于这个数直接返回0。

上界溢出的条件是`bin(x) = 0 10011101 00000000000000000000000`，此时s=0，exp=127+31，frac=0。表示的数是1.0*2**32，也就是TMax，大于这个数就直接返回TMax。

其他数字考虑`exp = 127+23`这个临界。如果大于这个数，需要将frac右移。如果小于这个数，需要将frac左移。

#### 代码

```c
int floatFloat2Int(unsigned uf) {
  //unsigned frac = uf & 0x007fffff;
  int frac = (uf & 0x007fffff) | 0x00800000;
  int exp = ((uf>>23) & 0xff) - 127;
  int s = uf>>31;
  int tar = 0;
  if (s)
    s = -1;
  else 
    s = 1;
  
  if (exp > 31)
    return 0x80000000;
  if (exp < 0)
    return 0;
  if (exp > 23)
    tar = s * (frac << (exp - 23));
  else if (exp < 23)
    tar = s * (frac >> (23 - exp));
  return tar;
}
```

### floatPower2

#### 描述

> /*
>
>  ** floatPower2 - Return bit-level equivalent of the expression 2.0^x*
>
>  **  (2.0 raised to the power x) for any 32-bit integer x.*
>
>  **  The unsigned value that is returned should have the identical bit*
>
>  **  representation as the single-precision floating-point number 2.0^x.*
>
>  **  If the result is too small to be represented as a denorm, return*
>
>  **  0. If too large, return +INF.*
>
>  *  Legal ops: Any integer/unsigned operations incl. \|\|, &&. Also if, while 
>
>  **  Max ops: 30* 
>
>  **  Rating: 4*
>
>  **/*

给出一个无符号整数x，将其看作一个浮点数，返回`2**x`。

#### 思路

参考上一题。

需要考虑的临界值：

`bin(x) = 0 00000000 00000000000000000000001`，此数是2**((-126)+(-23))。

`bin(x) = 0 00000001 00000000000000000000000`，此数是2**(-126)。

`bin(x) = 0 11111111 00000000000000000000000` ，此数是2**(128)。

#### 代码

```c
unsigned floatPower2(int x) {
  /*
  int e = x + 127;
  if (e<0)
    return 0;
  else if (e >= 0xff)
    return 0xff<<23;
  return (e << 23);
  */
  if (x < -149)
    return 0;
  if (x < -126)
    return 1 << (x + 126 + 23);
  if (x < 128)
    return (x+127) << 23;
  return (0xff<<23);
}
```

## 总结

我相信二进制数字的处理，肯定是计算机系统学习的基础。此实验提供了一个对二进制数字处理的练习，但是由于知识储备的限制，可能目前对二进制数字的处理方面我们学习者只能深入到这些层面。还不能进行复杂的处理。

个人感觉本次实验难度很大。原因可能是习惯10进制数字，在对二进制数字的思考上思路受限制。有许多实验都没有一个明确的思路。但是实验后回顾时感觉收获颇多。例如利用补码和本身不同的特性实现逻辑符`!`，利用二分法查找位数，判断大于等于0的方法等等。

本次实验就算是给自己的计算机系统学习之路开一个头吧。

![由于ubuntu虚拟机上时间限制通不过，在wsl上运行](/assets/CSAPP/QQ图片20200721133631.png)

