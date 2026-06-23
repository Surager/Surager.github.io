---
layout: comments
title: 留言
permalink: /comments/
---

## 友情链接

{% for friend in site.data.friends %}
<a href="{{ friend.url }}">{{ friend.url }}</a> ── {{ friend.content }} 
{% endfor %}

交换友情链接请在下面的评论区留言~

## 说点啥

> 文明发言嗷~
{: .admonition}
{: .info}
