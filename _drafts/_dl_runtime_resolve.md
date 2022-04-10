---
title: _dl_runtime_resolve
tags:
  - binary
---

# _dl_runtime_resolve

## 渊源

至于`_dl_runtime_resolve`是干什么的，想必看完了动态链接的知识之后就有所了解了。[动态链接——Surager's blog](https://surager.github.io/_posts/2020-01-26-%E5%8A%A8%E6%80%81%E9%93%BE%E6%8E%A5/)

根据延时绑定机制，在还没有使用一个外部函数的时候，链接器会将plt表的第二条指令的地址填入GOT表中。然后一步步跳转到`_dl_runtime_resolve`函数当中，将真正的函数地址填入GOT表中实现跳转。

## 重走取经路

👴认为，只要把`_dl_runtime_resolve`的过程搞清楚了，对他的利用就不是很麻烦了。因此我们走一遍过程。

**1.**通过link_map找到`.dynamic`，然后通过它找到各个相关的段。包括`.dynstr`、`.dynsym`、`.rel.plt`。

