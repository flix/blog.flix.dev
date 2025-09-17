+++
title = "Print Debugging in an Effectful World"
description = "A discussion of how the Flix type and effect system supports print-debugging."
date = 2025-09-15
authors = ["Magnus Madsen"]

[taxonomies]
tags = ["effects", "language-design", "flix"]
+++

> **"Every lie we tell incurs a debt to the truth. Sooner or later, that debt is paid."**

— Valery Legasov (*Jared Harris, Chernobyl 2019*)

Every lie we tell to a **type system** incurs a debt that sooner or later must
be paid. For memory-safe programming languages that debt is typically a runtime
type error (e.g. a `ClassCastException`, a `TypeError: foo is not a function`,
and so). For memory-unsafe languages that debt is typically memory corruption
(e.g. a `segmentation fault` or arbitrary code execution). 

But what happens when you lie to the **effect system**? Nothing good...

To understand why, let us look at how the Flix compiler uses effects:

- Flix relies on the effect system to perform **deadcode elimination** -- that
  is the Flix compiler eliminates pure expressions whose results are not needed,
  including entire let-bindings whose variables are unused.

- Flix relies on the effect system to perform whole-program **inlining and value
  propagation** -- that is moving let-bindings and statements around. Hence
  changing the order of execution. 

- Flix relies on the effect system to separate control-pure and control-impure
  code to support effect handlers. In particular, control-pure code (i.e. code
  that does not trigger an effect) is compiled to code without support for
  capturing the current deliminated continuation. 

These are scary program transformations!

Hence when a Flix programmer writes a function:

```flix
def add(x: Int32, y: Int32): Int32 \ { } = x + y
                                  // ^^^ empty effect set
```

We -- the Flix language designers -- are extremely paranoid about ensuring that
the purity of the function is not a lie.



<div class="hljs-deletion">


PL designer painful tradeoffs:
- Ultra fast compiler vs ultra deep optimization
-Ultra expressive type systems vs. inference
-Ultra expressive type systems vs. error messages
- Escape hatches vs. everytbhing.

Part of being a programming language designer is making difficult trade-offs.
In In this blog post, Lifting the veil from a PL designers point of view.

Add some quotes from HackerNews


> Ever tried adding a simple print statement for debugging purposes while coding
> in effectful lang? compiler: "NNNOOOOO!!!! THIS IS AN ERROR; I WILL NEVER
> COMPILE THIS NONSENSE YOU __MUST__ SPECIFY CONSOLE EFFECT WAAARGHH!11" 

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

# Look Ma': No Macros!

Rust has ...