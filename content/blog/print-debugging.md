+++
title = "Print Debugging in an Effectful World"
description = "..."
date = 2025-09-15
authors = ["Magnus Madsen"]

[taxonomies]
tags = ["effects", "language-design", "flix"]
+++

> **"Every lie we tell incurs a debt to the truth. Sooner or later, that debt is paid."**

— Valery Legasov (*Jared Harris, Chernobyl 2019*)

<div style="color: #ff00ff;">




Add some quotes from HackerNews

In this blog post, Lifting the veil from a PL designers point of view.

What we expect from a type system

What we expect from an effect system

The first lie:

```flix

```

We can use it 


```flix
...

```

The problem with lies is not the lie itself, it is its consequences.

The optimizer wrecks havoc

Fixing it with more lies:

```
intrododucing a local variable
```


```
forcing the argument to pass through
```


# A better solution, flix style




## Getting source and line offset

- THe debug pseudo macro, and how broken it is...


## Other Lies

Everything is printable

Getting the loc and offset is pure

</div>