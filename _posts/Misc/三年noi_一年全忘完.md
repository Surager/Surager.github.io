layout: post
title:  "三年noi 一年全忘完"
date:   2020-01-19
desc: "三年noi 一年全忘完"
keywords: "noi,算法"
categories: [HTML]
tags: [MISC]
icon: icon-html

> 曾经梦想 已化为无尽的泡影

# 三年noip

初中开始接触pascal语言，学得真是不咋地，连函数的概念都没搞清楚。朋友下载了个源代码想跑跑玩玩，运行后end处报错，结果他就干脆把所有的end去掉只剩一个。当时我真是没看出他有啥不对劲来，今天一想起来我就想把他打一顿。

高一的时候学了c++的竞赛基础。期间参加了提高组的初赛，没过。后来又继续学了数据结构，什么图树深度搜索广度搜索天天练。上课全程在听，但是一到上机全机房就变成了一个小型网吧。后来一想，当时就是在玩......结果数据结构就学得很烂。回学校班主任强行拉住了带队老师，通知九霄云外，我就没赶上报名的末班车。直接gg。

到了大学，没进入自己喜欢的专业，考个慧与班，一脸懵逼地进了。既然都回来了，那就重拾老本行，继续干一波。

#  哇，算法

写几个比较基础入门的算法

## 排序——有本事不会

### 桶排序——超时助手

思路：

开一个很大很大的数组，以他的下标为计数原则。

代码实现：

`cin>>k`之后`a[k]++;`，打印：`while(a[i]){cout<<i<<" ";a[i]--;}`

### 选择排序

基本思路：

把整个数组看成无序的，每次拿一个最小的放在前面组成有序的。

例如：

```
[2,5,3,1,4]

1,[2,5,3,4]

1,2,[5,3,4]

1,2,3,[5,4]

1,2,3,4,5[]
```

代码实现：

```c++
for (int i =0;i<n;i++)
{
    k=i;
    for (int j=i+1;j<n;j++) //无序列遍历
        if (a[j]<a[k]) k=j;
    if (k!=i)
    {
        int t=a[k];   //将寻找到的数放在有序列最后
        a[k]=a[i];
        a[i]=k;
    }
}
```

### 冒泡排序

思路：

一个一个比下去，把最大的放在后面。

代码实现：

```c++
for (int i=0;i<n-1;i++)
    for (int j=0;j<n-1;j++)
        if (a[j]>a[j+1])
        {
            int t=a[j];
            a[j]=a[i];
            a[i]=t;
        }
```

但是这样会产生一个问题，可能出现中途已经有序而仍然在进行循环的情况。

所以进行一下改良，设置一个变量flag判断是否进行了交换：

```c++
do{
	flag=true;
	for (int j=0;j<n-i-1;j++)
        if (a[j]>a[j+1])
        {
            int t=a[j];
            a[j]=a[j+1];
            a[j+1]=t;
            flag=false;  //有交换，则不停止
        }				 //团长：不要停下来啊（指排序
    i++;
}while(!flag);
```

### 插入排序

思路：

把第一个数看成有序列，然后把后边的每一个数插入到有序列的适当位置就可了。

例如：
```
[2],5,3,1,4

[2,5],3,1,4

[2,3,5],1,4

[1,2,3,5],4

[1,2,3,4,5]
```
代码实现：

```c++
for (int i=1;i<n;i++)
{
    x=a[i];
    j=i-1;
    while (x<a[j])	//在有序列中遍历寻找插入点
    {
        a[j+1]=a[j];
        j--;
    }
    a[j+1]=x;
}
```

### 快速排序

思路：

~~#include \<algorithm\> sort(a,0,9);~~

选择一个数当基准，然后从两边遍历。到中间的时候把基准插入，保证左边小右边大。

代码实现：

```c++
quicksort（int *a,int low,int high)
{
	if (low<high)
	{
		int i=low;
		int j=high;
		int k=a[low];
		while (i<j)
		{
			while (i<j && a[j]>=k) j--;
			if (i<j) a[i++]=a[j];
			while (i<j && a[i]<k) i++;
			if (i<j) a[j--]=a[i];
		}								//两边交换以保证大小
		a[i]=k;
		quicksort(a,low,i-1);
		quicksort(a,j+1,high);
	}
}
```

递归就完事儿了。

### 归并排序

思路：

把两个有序数组归并到一起，还是有序的。

代码实现：

```c++
mergesort (int *a,int s,int t)
{
	int r[t];
	if (s==t) return;
    int m=(s+t)/2;
    mergesort(a,s,m);
    mergesort(a,m+1,t);
    int i=s;
    int j=m+1;
    int k=s;
    while (i<=m && j<=t)
    {
        if (a[i]>=a[j])
        {
            r[k++]=a[j++];
        }
        else
        {
            r[k++]=a[i++];
        }
    }
    while (i<=m)
    {
        r[k++]=a[i++];
    }
    while (j<=t)
    {
        r[k++]=a[j++];
    }							//把剩下的数据全都放进去
    for (int l=s;l<=t;l++)
        a[l]=r[l];				//copy回原来的数组
}
```

## 高精度计算

其实这玩意就是涉及到字符串和数字的转化以及进位借位的知识罢了。

### 高精度加法

#### 转化方法：

思路：减去字符0

```c++
lena=strlen(a1);
lenb=strlen(b1);
for (int i=0;i<lena;i++) a[lena-i]=a1[i]-'0';
for (int i=0;i<lenb;i++) b[lenb-i]=b1[i]-'0';
```

模拟加法过程：

```c++
x=0;
lenc=1;
while (lenc<=lena||lenc<=lenb)
{
    c[lenc]=a[lenc]+b[lenc]+x;
    x=c[lenc]/10;
    c[lenc]=c[lenc]%10;
    lenc++;
}
c[lenc]=x;
if (c[lenc]==0) lenc--;
```

### 高精度减法

处理被减数和减数的关系：

```c++
if (strlen(n1)<strlen(n2) || strlen(n1)==strlen(n2) && strcmp(n1,n2)<0)
{
    strcpy(n,n1);
    strcpy(n1,n2);
    strcpy(n2,n);
    cout<<"-";
}
```

模拟竖式减法：

```c++
i=1;
while (i<=lena||i<=lenb)
{
    if (a[i]<b[i])
    {
         a[i]+=10;
         a[i+1]-=1;		//借位
    }
    c[i]=a[i]-b[i];
    i++;
}
lenc=i;
while ((c[lenc]==0) && (lenc>1)) lenc--;
```

### 高进度乘法

```c
for (int i=1;i<=lena;i++){
        x=0;
        for (int j=1;j<=lenb;j++){
            c[i+j-1] += a[i]*b[j]+x;
            x=c[i+j-1]/10;
            c[i+j-1] %= 10;
        }
        c[i+lenb]=x;
    }
    lenc = lena+lenb;
```

涉及到进位。

### 高精度除法

