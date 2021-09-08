---

title: CSAPP实验bomblab
tags:
  - binary
---

## 渊源

刚进入蓝🐋的时候👴想当②进制🖐，当时做了一次💣实验，但是当时是用ida做的，加上不会看汇编，导致lab6和sercet_lab不会做。这次会了汇编，来做做vanvan。

做了三天，主要是因为👴是蓝🐕。

## 获取实验并使用


从[http://csapp.cs.cmu.edu/3e/labs.html](http://csapp.cs.cmu.edu/3e/labs.html)获取。获取方法是`点击实验后面的Self-Study Handout`。

获取一个.tar文件，直接解压或者使用命令解压

```sh
tar -xvf bomb.tar
```

共有以下文件。

```
 ± tree
.
├── README
├── bomb
└── bomb.c

0 directories, 3 files
```

其中`README`没卵用，`bomb`是我们需要通关的程序，`bomb.c`是程序的main函数部分，由于加了`-g`编译参数，用gdb的时候可以看到main函数的源码。

### 获得反汇编

可以直接使用命令：

```sh
$ objdump -d bomb > bomb.d
```

然后直接在`bomb.d`中查看。

直接用gdb动态调试也行，当我没说。

直接拖进ida里面F5也行，也当我没说。

## 用法

`bomb.c`中已经说的很清楚了：

```c
	if (argc == 1) {  
	infile = stdin;
    } 

    /* When run with one argument <file>, the bomb reads from <file> 
     * until EOF, and then switches to standard input. Thus, as you 
     * defuse each phase, you can add its defusing string to <file> and
     * avoid having to retype it. */
    else if (argc == 2) {
	if (!(infile = fopen(argv[1], "r"))) {
	    printf("%s: Error: Couldn't open %s\n", argv[0], argv[1]);
	    exit(8);
	}
    }

    /* You can't call the bomb with more than 1 command line argument. */
    else {
	printf("Usage: %s [<input_file>]\n", argv[0]);
	exit(8);
    }
```

要么直接`./bomb`运行，然后手动输入；要么把答案写在一个文件里，用`./bomb inputfile`运行。文件输入的时候，读到EOF会返回到stdin。

## 题解

### phase_1

汇编代码：

```assembly
0000000000400ee0 <phase_1>:
  400ee0:	48 83 ec 08          	sub    $0x8,%rsp
  400ee4:	be 00 24 40 00       	mov    $0x402400,%esi   		# 0x402400:       "Border relations with Canada have never been better."
  400ee9:	e8 4a 04 00 00       	callq  401338 <strings_not_equal>
  400eee:	85 c0                	test   %eax,%eax
  400ef0:	74 05                	je     400ef7 <phase_1+0x17>
  400ef2:	e8 43 05 00 00       	callq  40143a <explode_bomb>
  400ef7:	48 83 c4 08          	add    $0x8,%rsp
  400efb:	c3                   	retq
```

比较输入的字符串和0x402400处的字符串是否一样，如果不一样💣爆炸。

查看0x402400：

```sh
pwndbg> x/s 0x402400
0x402400:       "Border relations with Canada have never been better."
```

所以第一关的答案是：

`Border relations with Canada have never been better.`

### phase_2

汇编代码：

```assembly
0000000000400efc <phase_2>:
  400efc:	55                   	push   %rbp
  400efd:	53                   	push   %rbx
  400efe:	48 83 ec 28          	sub    $0x28,%rsp  			# stack init
  400f02:	48 89 e6             	mov    %rsp,%rsi
  400f05:	e8 52 05 00 00       	callq  40145c <read_six_numbers>	# read six numbers
  400f0a:	83 3c 24 01          	cmpl   $0x1,(%rsp)			# first number: 1
  400f0e:	74 20                	je     400f30 <phase_2+0x34>
  400f10:	e8 25 05 00 00       	callq  40143a <explode_bomb>
  400f15:	eb 19                	jmp    400f30 <phase_2+0x34>

<phase_2+0x1b>
  400f17:	8b 43 fc             	mov    -0x4(%rbx),%eax
  400f1a:	01 c0                	add    %eax,%eax			# 乘2
  400f1c:	39 03                	cmp    %eax,(%rbx)			# second number: 2
  400f1e:	74 05                	je     400f25 <phase_2+0x29>
  400f20:	e8 15 05 00 00       	callq  40143a <explode_bomb>

<phase_2+0x29>
  400f25:	48 83 c3 04          	add    $0x4,%rbx
  400f29:	48 39 eb             	cmp    %rbp,%rbx
  400f2c:	75 e9                	jne    400f17 <phase_2+0x1b>

  400f2e:	eb 0c                	jmp    400f3c <phase_2+0x40>

<phase_2+0x34>
  400f30:	48 8d 5c 24 04       	lea    0x4(%rsp),%rbx		# the second number
  400f35:	48 8d 6c 24 18       	lea    0x18(%rsp),%rbp		
  400f3a:	eb db                	jmp    400f17 <phase_2+0x1b>

  400f3c:	48 83 c4 28          	add    $0x28,%rsp
  400f40:	5b                   	pop    %rbx
  400f41:	5d                   	pop    %rbp
  400f42:	c3                   	retq  
```

看起来有点麻烦，改写一下。

```c
int phase_2(int *a){
	int b[6];
	read_six_numbers(b);
	if (b[0] != 1)
		explode_bomb();
	for (int i = 1;i <= 5;i++){
		int t = b[i-1];
		if (2 * t != b[i])
			explode_bomb();
	}
}
```

一目了然，答案：

`1 2 4 8 16 32`

### phase_3

汇编代码：

```assembly
0000000000400f43 <phase_3>:
  400f43:	48 83 ec 18          	sub    $0x18,%rsp

  400f47:	48 8d 4c 24 0c       	lea    0xc(%rsp),%rcx
  400f4c:	48 8d 54 24 08       	lea    0x8(%rsp),%rdx
  400f51:	be cf 25 40 00       	mov    $0x4025cf,%esi
  400f56:	b8 00 00 00 00       	mov    $0x0,%eax
  400f5b:	e8 90 fc ff ff       	callq  400bf0 <__isoc99_sscanf@plt> 	# scanf("%d %d",a,b)
  400f60:	83 f8 01             	cmp    $0x1,%eax 			
  400f63:	7f 05                	jg     400f6a <phase_3+0x27>
  400f65:	e8 d0 04 00 00       	callq  40143a <explode_bomb>

<phase_3+0x27>
  400f6a:	83 7c 24 08 07       	cmpl   $0x7,0x8(%rsp)		# if (a>0x7) explode_bomb();
  400f6f:	77 3c                	ja     400fad <phase_3+0x6a>

  400f71:	8b 44 24 08          	mov    0x8(%rsp),%eax
  400f75:	ff 24 c5 70 24 40 00 	jmpq   *0x402470(,%rax,8)	# jmp 0x400fb9
  400f7c:	b8 cf 00 00 00       	mov    $0xcf,%eax
  400f81:	eb 3b                	jmp    400fbe <phase_3+0x7b>
  400f83:	b8 c3 02 00 00       	mov    $0x2c3,%eax
  400f88:	eb 34                	jmp    400fbe <phase_3+0x7b>
  400f8a:	b8 00 01 00 00       	mov    $0x100,%eax
  400f8f:	eb 2d                	jmp    400fbe <phase_3+0x7b>
  400f91:	b8 85 01 00 00       	mov    $0x185,%eax
  400f96:	eb 26                	jmp    400fbe <phase_3+0x7b>
  400f98:	b8 ce 00 00 00       	mov    $0xce,%eax
  400f9d:	eb 1f                	jmp    400fbe <phase_3+0x7b>
  400f9f:	b8 aa 02 00 00       	mov    $0x2aa,%eax
  400fa4:	eb 18                	jmp    400fbe <phase_3+0x7b>
  400fa6:	b8 47 01 00 00       	mov    $0x147,%eax
  400fab:	eb 11                	jmp    400fbe <phase_3+0x7b>


  400fad:	e8 88 04 00 00       	callq  40143a <explode_bomb>
  400fb2:	b8 00 00 00 00       	mov    $0x0,%eax
  400fb7:	eb 05                	jmp    400fbe <phase_3+0x7b>
  400fb9:	b8 37 01 00 00       	mov    $0x137,%eax		# if (b != 0x137) explode_bomb();
  400fbe:	3b 44 24 0c          	cmp    0xc(%rsp),%eax
  400fc2:	74 05                	je     400fc9 <phase_3+0x86>
  400fc4:	e8 71 04 00 00       	callq  40143a <explode_bomb>

  400fc9:	48 83 c4 18          	add    $0x18,%rsp
  400fcd:	c3                   	retq
```

读入两个数，第一个数不能大于7，然后直接跳转，第二个数等于0x137，结束...中间的一大片根本没用到

答案：

`1 311`

### phase_4

汇编代码：

```assembly
000000000040100c <phase_4>:
  40100c:	48 83 ec 18          	sub    $0x18,%rsp

  401010:	48 8d 4c 24 0c       	lea    0xc(%rsp),%rcx
  401015:	48 8d 54 24 08       	lea    0x8(%rsp),%rdx
  40101a:	be cf 25 40 00       	mov    $0x4025cf,%esi
  40101f:	b8 00 00 00 00       	mov    $0x0,%eax
  401024:	e8 c7 fb ff ff       	callq  400bf0 <__isoc99_sscanf@plt> 	# scanf("%d %d",a,b)
  401029:	83 f8 02             	cmp    $0x2,%eax
  40102c:	75 07                	jne    401035 <phase_4+0x29>

  40102e:	83 7c 24 08 0e       	cmpl   $0xe,0x8(%rsp)		# <=14
  401033:	76 05                	jbe    40103a <phase_4+0x2e>

  401035:	e8 00 04 00 00       	callq  40143a <explode_bomb>
  40103a:	ba 0e 00 00 00       	mov    $0xe,%edx
  40103f:	be 00 00 00 00       	mov    $0x0,%esi
  401044:	8b 7c 24 08          	mov    0x8(%rsp),%edi
  401048:	e8 81 ff ff ff       	callq  400fce <func4>		# fun4(a,0,14)
  40104d:	85 c0                	test   %eax,%eax
  40104f:	75 07                	jne    401058 <phase_4+0x4c>
  401051:	83 7c 24 0c 00       	cmpl   $0x0,0xc(%rsp)
  401056:	74 05                	je     40105d <phase_4+0x51>
  401058:	e8 dd 03 00 00       	callq  40143a <explode_bomb>

  40105d:	48 83 c4 18          	add    $0x18,%rsp
  401061:	c3                   	retq
```

读入两个数，第一个数要小于等于14，第二个数要等于0。此外还调用了一个函数func4()。

```assembly
0000000000400fce <func4>: 		func4(a,b,c)
  400fce:	48 83 ec 08          	sub    $0x8,%rsp
// eax: t1 		ecx:t2
  400fd2:	89 d0                	mov    %edx,%eax			# t1 = c
  400fd4:	29 f0                	sub    %esi,%eax			# t1 -= b
  400fd6:	89 c1                	mov    %eax,%ecx			# t2 = t1
  400fd8:	c1 e9 1f             	shr    $0x1f,%ecx			# t2 >>= 31
  400fdb:	01 c8                	add    %ecx,%eax			# t1 += t2
  400fdd:	d1 f8                	sar    1,%eax			# t1 >>= 1 （算术）
  400fdf:	8d 0c 30             	lea    (%rax,%rsi,1),%ecx		# t2 += b+t1
  400fe2:	39 f9                	cmp    %edi,%ecx			# a <= t2 ?
  400fe4:	7e 0c                	jle    400ff2 <func4+0x24>

  400fe6:	8d 51 ff             	lea    -0x1(%rcx),%edx		# 
  400fe9:	e8 e0 ff ff ff       	callq  400fce <func4>		# func4(a,b,c-1)
  400fee:	01 c0                	add    %eax,%eax			# t1 *= 2
  400ff0:	eb 15                	jmp    401007 <func4+0x39>		# break

  400ff2:	b8 00 00 00 00       	mov    $0x0,%eax			# t1 = 0
  400ff7:	39 f9                	cmp    %edi,%ecx			# a >= t2 ?
  400ff9:	7d 0c                	jge    401007 <func4+0x39>		# break
  400ffb:	8d 71 01             	lea    0x1(%rcx),%esi		# 
  400ffe:	e8 cb ff ff ff       	callq  400fce <func4>		# func4(a,b+1,c)
  401003:	8d 44 00 01          	lea    0x1(%rax,%rax,1),%eax		# t1 *= 2

  401007:	48 83 c4 08          	add    $0x8,%rsp
  40100b:	c3                   	retq   
```

很nt的一个递归函数。有很多运算，改写一下得到c代码。

```c
int func4(a,b,c){  
	int t1,t2;
	t1 = c - b;  // 14
	t2 = t1 >> 31; // 0
	t1 += t2; // 14
	t1 >>= 1;(算术) // 7
	t2 += b + t1; // 7
	if (a <= t2){
		t1 = 0;
		if (a >= t2)
			return t1;
		func4(a,b+1,c);
		t1 *= 2;
		return t1;
	}
	else {
		func4(a,b,c-1);
		t1 *= 2;
		return t1;
	}
}
```

由于第一次调用时有`b=0``c=14`，可以直接算出部分临时变量的值。根据  `40104d:test %eax,%eax`和`40104f:jne 401058`可以判断我们需要返回一个0。根据我们算出来的值，进入`if (a <= t2)`，再进入`if (a >= t2)`，即返回0，而满足此条件只要`a=7`即可。

所以，答案是：

`7 0`

### phase_5

```assembly
0000000000401062 <phase_5>: 
  401062:	53                   	push   %rbx
  401063:	48 83 ec 20          	sub    $0x20,%rsp

  401067:	48 89 fb             	mov    %rdi,%rbx
  40106a:	64 48 8b 04 25 28 00 	mov    %fs:0x28,%rax
  401071:	00 00 
  401073:	48 89 44 24 18       	mov    %rax,0x18(%rsp)
  401078:	31 c0                	xor    %eax,%eax
  40107a:	e8 9c 02 00 00       	callq  40131b <string_length>
  40107f:	83 f8 06             	cmp    $0x6,%eax
  401082:	74 4e                	je     4010d2 <phase_5+0x70>
  
  401084:	e8 b1 03 00 00       	callq  40143a <explode_bomb>
  401089:	eb 47                	jmp    4010d2 <phase_5+0x70>
  
  40108b:	0f b6 0c 03          	movzbl (%rbx,%rax,1),%ecx
  40108f:	88 0c 24             	mov    %cl,(%rsp)
  401092:	48 8b 14 24          	mov    (%rsp),%rdx
  401096:	83 e2 0f             	and    $0xf,%edx
  401099:	0f b6 92 b0 24 40 00 	movzbl 0x4024b0(%rdx),%edx        # x/s 0x4024b0
  4010a0:	88 54 04 10          	mov    %dl,0x10(%rsp,%rax,1)      # 0x4024b0 <array>:  "maduiersnfotvbyl"
  
  4010a4:	48 83 c0 01          	add    $0x1,%rax
  4010a8:	48 83 f8 06          	cmp    $0x6,%rax
  4010ac:	75 dd                	jne    40108b <phase_5+0x29>
  
  4010ae:	c6 44 24 16 00       	movb   $0x0,0x16(%rsp)
  4010b3:	be 5e 24 40 00       	mov    $0x40245e,%esi             # string: "flyers"
  4010b8:	48 8d 7c 24 10       	lea    0x10(%rsp),%rdi
  4010bd:	e8 76 02 00 00       	callq  401338 <strings_not_equal>
  4010c2:	85 c0                	test   %eax,%eax
  4010c4:	74 13                	je     4010d9 <phase_5+0x77>
  4010c6:	e8 6f 03 00 00       	callq  40143a <explode_bomb>
  4010cb:	0f 1f 44 00 00       	nopl   0x0(%rax,%rax,1)
  4010d0:	eb 07                	jmp    4010d9 <phase_5+0x77>
  
<phase_5+0x70>
  4010d2:	b8 00 00 00 00       	mov    $0x0,%eax
  4010d7:	eb b2                	jmp    40108b <phase_5+0x29>
  4010d9:	48 8b 44 24 18       	mov    0x18(%rsp),%rax
  4010de:	64 48 33 04 25 28 00 	xor    %fs:0x28,%rax
  4010e5:	00 00 
  4010e7:	74 05                	je     4010ee <phase_5+0x8c>

  4010e9:	e8 42 fa ff ff       	callq  400b30 <__stack_chk_fail@plt>
  4010ee:	48 83 c4 20          	add    $0x20,%rsp
  4010f2:	5b                   	pop    %rbx
  4010f3:	c3                   	retq   
```

这个函数有大约三个部分。`401073~401082`部分，读入一个长度必须为6的字符串，否则💣爆炸。`40108b~4010ac`部分将读入字符进行操作`&0xf`，即取低4个二进制位，根据低四位的值在`0x4024b0 <array>:  "maduiersnfotvbyl"`处的字符串取出字符。`4010ae~4010d0`部分，根据取出的字符和0x40245e处的字符串"flyers"比较。

所以我们需要的字符串必须满足低四位分别为：`0x9 0xf 0xe 0x5 0x6 0x7`

于是我选择的字符串是：

`9on567`

### phase_6

汇编代码：

```assembly
00000000004010f4 <phase_6>: // 4 3 2 1 6 5
  4010f4:	41 56                	push   %r14
  4010f6:	41 55                	push   %r13
  4010f8:	41 54                	push   %r12
  4010fa:	55                   	push   %rbp
  4010fb:	53                   	push   %rbx
  4010fc:	48 83 ec 50          	sub    $0x50,%rsp
  
  401100:	49 89 e5             	mov    %rsp,%r13
  401103:	48 89 e6             	mov    %rsp,%rsi
  401106:	e8 51 03 00 00       	callq  40145c <read_six_numbers>
  
  40110b:	49 89 e6             	mov    %rsp,%r14
  40110e:	41 bc 00 00 00 00    	mov    $0x0,%r12d
  
  401114:	4c 89 ed             	mov    %r13,%rbp
  401117:	41 8b 45 00          	mov    0x0(%r13),%eax
  40111b:	83 e8 01             	sub    $0x1,%eax
  40111e:	83 f8 05             	cmp    $0x5,%eax
  401121:	76 05                	jbe    401128 <phase_6+0x34>
  
  401123:	e8 12 03 00 00       	callq  40143a <explode_bomb>
  
  401128:	41 83 c4 01          	add    $0x1,%r12d
  40112c:	41 83 fc 06          	cmp    $0x6,%r12d
  401130:	74 21                	je     401153 <phase_6+0x5f>
  401132:	44 89 e3             	mov    %r12d,%ebx
  
  401135:	48 63 c3             	movslq %ebx,%rax
  401138:	8b 04 84             	mov    (%rsp,%rax,4),%eax
  40113b:	39 45 00             	cmp    %eax,0x0(%rbp)
  40113e:	75 05                	jne    401145 <phase_6+0x51>
  
  401140:	e8 f5 02 00 00       	callq  40143a <explode_bomb>
  
  401145:	83 c3 01             	add    $0x1,%ebx
  401148:	83 fb 05             	cmp    $0x5,%ebx
  40114b:	7e e8                	jle    401135 <phase_6+0x41>
  
  40114d:	49 83 c5 04          	add    $0x4,%r13
  401151:	eb c1                	jmp    401114 <phase_6+0x20>
// 上面这段401114~401151的功能是检测输入的数字是否有重复并且是否满足 0<x<=6


  401153:	48 8d 74 24 18       	lea    0x18(%rsp),%rsi
  401158:	4c 89 f0             	mov    %r14,%rax
  40115b:	b9 07 00 00 00       	mov    $0x7,%ecx
  
  401160:	89 ca                	mov    %ecx,%edx
  401162:	2b 10                	sub    (%rax),%edx
  401164:	89 10                	mov    %edx,(%rax)
  401166:	48 83 c0 04          	add    $0x4,%rax
  40116a:	48 39 f0             	cmp    %rsi,%rax
  40116d:	75 f1                	jne    401160 <phase_6+0x6c>
// 401160~40116d
for (int i = 0; i <= 5; i++){
    a[i] = 7 - a[i];
}
 
  40116f:	be 00 00 00 00       	mov    $0x0,%esi
  401174:	eb 21                	jmp    401197 <phase_6+0xa3>
  
  401176:	48 8b 52 08          	mov    0x8(%rdx),%rdx
  40117a:	83 c0 01             	add    $0x1,%eax
  40117d:	39 c8                	cmp    %ecx,%eax
  40117f:	75 f5                	jne    401176 <phase_6+0x82>
  401181:	eb 05                	jmp    401188 <phase_6+0x94>
  
  401183:	ba d0 32 60 00       	mov    $0x6032d0,%edx
  401188:	48 89 54 74 20       	mov    %rdx,0x20(%rsp,%rsi,2)
  40118d:	48 83 c6 04          	add    $0x4,%rsi
  401191:	48 83 fe 18          	cmp    $0x18,%rsi
  401195:	74 14                	je     4011ab <phase_6+0xb7>
  
  401197:	8b 0c 34             	mov    (%rsp,%rsi,1),%ecx
  40119a:	83 f9 01             	cmp    $0x1,%ecx
  40119d:	7e e4                	jle    401183 <phase_6+0x8f>
  
  40119f:	b8 01 00 00 00       	mov    $0x1,%eax
  4011a4:	ba d0 32 60 00       	mov    $0x6032d0,%edx
  4011a9:	eb cb                	jmp    401176 <phase_6+0x82>
// 上面这段根据a[i] = 7 - a[i]之后的序号将node填入栈中 
typedef struct node{
    int num;
    int order;
    struct node *next;
}
  
  4011ab:	48 8b 5c 24 20       	mov    0x20(%rsp),%rbx
  4011b0:	48 8d 44 24 28       	lea    0x28(%rsp),%rax
  4011b5:	48 8d 74 24 50       	lea    0x50(%rsp),%rsi
  4011ba:	48 89 d9             	mov    %rbx,%rcx
  4011bd:	48 8b 10             	mov    (%rax),%rdx
  4011c0:	48 89 51 08          	mov    %rdx,0x8(%rcx)
  4011c4:	48 83 c0 08          	add    $0x8,%rax
  4011c8:	48 39 f0             	cmp    %rsi,%rax
  4011cb:	74 05                	je     4011d2 <phase_6+0xde>
  
  4011cd:	48 89 d1             	mov    %rdx,%rcx
  4011d0:	eb eb                	jmp    4011bd <phase_6+0xc9>
// 根据刚才入栈的顺序，改变链表  
  
  4011d2:	48 c7 42 08 00 00 00 	movq   $0x0,0x8(%rdx)
  4011d9:	00 
  4011da:	bd 05 00 00 00       	mov    $0x5,%ebp
  4011df:	48 8b 43 08          	mov    0x8(%rbx),%rax
  4011e3:	8b 00                	mov    (%rax),%eax
  4011e5:	39 03                	cmp    %eax,(%rbx)
  4011e7:	7d 05                	jge    4011ee <phase_6+0xfa>
  4011e9:	e8 4c 02 00 00       	callq  40143a <explode_bomb>
  4011ee:	48 8b 5b 08          	mov    0x8(%rbx),%rbx
  4011f2:	83 ed 01             	sub    $0x1,%ebp
  4011f5:	75 e8                	jne    4011df <phase_6+0xeb>
// 检测是否是降序排列的  

  4011f7:	48 83 c4 50          	add    $0x50,%rsp
  4011fb:	5b                   	pop    %rbx
  4011fc:	5d                   	pop    %rbp
  4011fd:	41 5c                	pop    %r12
  4011ff:	41 5d                	pop    %r13
  401201:	41 5e                	pop    %r14
  401203:	c3                   	retq   
//
pwndbg> x/24x 0x6032d0
0x6032d0 <node1>:       0x0000014c      0x00000001      0x006032e0      0x00000000
0x6032e0 <node2>:       0x000000a8      0x00000002      0x006032f0      0x00000000
0x6032f0 <node3>:       0x0000039c      0x00000003      0x00603300      0x00000000
0x603300 <node4>:       0x000002b3      0x00000004      0x00603310      0x00000000
0x603310 <node5>:       0x000001dd      0x00000005      0x00603320      0x00000000
0x603320 <node6>:       0x000001bb      0x00000006      0x00000000      0x00000000

```

注释已经写的比较清楚了，不想写了。说实话，这一关挺好玩的。

答案：

`4 3 2 1 6 5`

### sercet_phase

这关有点难。首先直接`ctrl+f`查找"sercet_phase"，在`phase_defused`中找到了此函数的调用。

```assembly
  401630:	e8 0d fc ff ff       	callq  401242 <secret_phase>
```

直接对这个函数进行逆向。

```assembly
00000000004015c4 <phase_defused>:
  4015c4:	48 83 ec 78          	sub    $0x78,%rsp
  
  4015c8:	64 48 8b 04 25 28 00 	mov    %fs:0x28,%rax
  4015cf:	00 00 
  4015d1:	48 89 44 24 68       	mov    %rax,0x68(%rsp)
  4015d6:	31 c0                	xor    %eax,%eax
  4015d8:	83 3d 81 21 20 00 06 	cmpl   $0x6,0x202181(%rip)        # 603760 <num_input_strings>
  4015df:	75 5e                	jne    40163f <phase_defused+0x7b>
  
  4015e1:	4c 8d 44 24 10       	lea    0x10(%rsp),%r8
  4015e6:	48 8d 4c 24 0c       	lea    0xc(%rsp),%rcx
  4015eb:	48 8d 54 24 08       	lea    0x8(%rsp),%rdx
  4015f0:	be 19 26 40 00       	mov    $0x402619,%esi
  4015f5:	bf 70 38 60 00       	mov    $0x603870,%edi
  4015fa:	e8 f1 f5 ff ff       	callq  400bf0 <__isoc99_sscanf@plt>
  4015ff:	83 f8 03             	cmp    $0x3,%eax
  401602:	75 31                	jne    401635 <phase_defused+0x71>
  401604:	be 22 26 40 00       	mov    $0x402622,%esi
  401609:	48 8d 7c 24 10       	lea    0x10(%rsp),%rdi
  40160e:	e8 25 fd ff ff       	callq  401338 <strings_not_equal>
  401613:	85 c0                	test   %eax,%eax
  401615:	75 1e                	jne    401635 <phase_defused+0x71>
  401617:	bf f8 24 40 00       	mov    $0x4024f8,%edi
  40161c:	e8 ef f4 ff ff       	callq  400b10 <puts@plt>
  401621:	bf 20 25 40 00       	mov    $0x402520,%edi
  401626:	e8 e5 f4 ff ff       	callq  400b10 <puts@plt>
  40162b:	b8 00 00 00 00       	mov    $0x0,%eax
  401630:	e8 0d fc ff ff       	callq  401242 <secret_phase>
  401635:	bf 58 25 40 00       	mov    $0x402558,%edi
  40163a:	e8 d1 f4 ff ff       	callq  400b10 <puts@plt>
  40163f:	48 8b 44 24 68       	mov    0x68(%rsp),%rax
  401644:	64 48 33 04 25 28 00 	xor    %fs:0x28,%rax
  40164b:	00 00 
  40164d:	74 05                	je     401654 <phase_defused+0x90>
  
  40164f:	e8 dc f4 ff ff       	callq  400b30 <__stack_chk_fail@plt>
  401654:	48 83 c4 78          	add    $0x78,%rsp
  401658:	c3                   	retq   
  401659:	90                   	nop
  40165a:	90                   	nop
  40165b:	90                   	nop
  40165c:	90                   	nop
  40165d:	90                   	nop
  40165e:	90                   	nop
  40165f:	90                   	nop
```

`cmpl $0x6,0x202181(%rip)`其中0x202181+%rip是0x603760。记录的是你拆完💣的数量，到达6个的话就能绕过`jne 40163f`。执行`scanf`。格式符是"%d %d %s"。查看地址0x603870，发现是phase_4的输入。因此缺少一个%s。因为后面有`strings_not_equal`，猜测0x402622就是目标字符串地址。`0x402622: "DrEvil"`。所以，在`7 0`之后加上一个"DrEvil"即可进入`secret_phase`。

```assembly
0000000000401242 <secret_phase>:
  401242:	53                   	push   %rbx
  
  401243:	e8 56 02 00 00       	callq  40149e <read_line>
  401248:	ba 0a 00 00 00       	mov    $0xa,%edx
  40124d:	be 00 00 00 00       	mov    $0x0,%esi
  401252:	48 89 c7             	mov    %rax,%rdi
  401255:	e8 76 f9 ff ff       	callq  400bd0 <strtol@plt>
  40125a:	48 89 c3             	mov    %rax,%rbx
  40125d:	8d 40 ff             	lea    -0x1(%rax),%eax
  401260:	3d e8 03 00 00       	cmp    $0x3e8,%eax
  401265:	76 05                	jbe    40126c <secret_phase+0x2a>
  401267:	e8 ce 01 00 00       	callq  40143a <explode_bomb>
  40126c:	89 de                	mov    %ebx,%esi
  40126e:	bf f0 30 60 00       	mov    $0x6030f0,%edi
  401273:	e8 8c ff ff ff       	callq  401204 <fun7>
  401278:	83 f8 02             	cmp    $0x2,%eax
  40127b:	74 05                	je     401282 <secret_phase+0x40>
  40127d:	e8 b8 01 00 00       	callq  40143a <explode_bomb>
  401282:	bf 38 24 40 00       	mov    $0x402438,%edi
  401287:	e8 84 f8 ff ff       	callq  400b10 <puts@plt>
  40128c:	e8 33 03 00 00       	callq  4015c4 <phase_defused>
  
  401291:	5b                   	pop    %rbx
  401292:	c3                   	retq   
  401293:	90                   	nop
  401294:	90                   	nop
  401295:	90                   	nop
  401296:	90                   	nop
  401297:	90                   	nop
  401298:	90                   	nop
  401299:	90                   	nop
  40129a:	90                   	nop
  40129b:	90                   	nop
  40129c:	90                   	nop
  40129d:	90                   	nop
  40129e:	90                   	nop
  40129f:	90                   	nop
```

使用`strtol`将读取的字符转化成数字，然后判断这个数小于0x3e8，之后将一个二叉树的根节点和所输入的数作为参数调用func7，目标是返回一个2。

```assembly
0000000000401204 <fun7>:
  401204:	48 83 ec 08          	sub    $0x8,%rsp
  
  401208:	48 85 ff             	test   %rdi,%rdi
  40120b:	74 2b                	je     401238 <fun7+0x34>
  
  40120d:	8b 17                	mov    (%rdi),%edx
  40120f:	39 f2                	cmp    %esi,%edx
  401211:	7e 0d                	jle    401220 <fun7+0x1c>
  401213:	48 8b 7f 08          	mov    0x8(%rdi),%rdi
  401217:	e8 e8 ff ff ff       	callq  401204 <fun7>
  40121c:	01 c0                	add    %eax,%eax
  40121e:	eb 1d                	jmp    40123d <fun7+0x39>
  
  401220:	b8 00 00 00 00       	mov    $0x0,%eax
  401225:	39 f2                	cmp    %esi,%edx
  401227:	74 14                	je     40123d <fun7+0x39>
  
  401229:	48 8b 7f 10          	mov    0x10(%rdi),%rdi
  40122d:	e8 d2 ff ff ff       	callq  401204 <fun7>
  401232:	8d 44 00 01          	lea    0x1(%rax,%rax,1),%eax
  401236:	eb 05                	jmp    40123d <fun7+0x39>
  
  401238:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
  
  40123d:	48 83 c4 08          	add    $0x8,%rsp
  401241:	c3                   	retq   
```

一顿分析，得到c代码

```c
int func7(int *a,int b){
    if (a == 0){
        return -1;
    }
    if (*a > b){
        a = a->left;
        func7(a,b);
        return result*2;
    }
    else{
        result = 0;
        if (*a == b){
            return 0;
        }
        a = a->right;
        result = func7(a,b);
        return result*2+1;
    }
}
```

这样的话就非常清晰了。

二叉树结构如下。

<img src="\assets\CSAPP\IMG_20200730_165637.jpg" alt="IMG_20200730_165637" style="zoom: 67%;" />

要想返回一个2的话，我们需要进入`if (*a > b)`这个分支，并在下一层func7中得到1，那么我们的b应该小于24。

要想返回一个1的话，我们需要进入`else`分支，并在下一层func7中得到一个0，那么我们的b应该大于8。

要想返回一个0的话，我们需要进入`else`分支，并进入`if (*a == b)`这个分支，所以我们的b应该等于16。

所以，答案是：

`16`

## 总结

CSAPP的第二个实验。个人感觉难度没有datalab高。也没有第一次的那个版本难度高。可能是因为本人做pwn题目比较多对汇编比较熟悉。

通过本次实验，感受到了静态分析的局限性，动态调试可以有效的观察各个寄存器和内存的变化，是一种值得学习的调试方法。

![QQ图片20200730174130](\assets\CSAPP\QQ图片20200730174130.png)