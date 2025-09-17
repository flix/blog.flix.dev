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

- Flix relies on the effect system to *separate control-pure and control-impure
  code* to support effect handlers. In particular, control-pure code (i.e. code
  that does not trigger an effect) is compiled to code without support for
  capturing the current deliminated continuation. 

These are scary program transformations!

Hence when a Flix programmer writes a function:

```flix
def add(x: Int32, y: Int32): Int32 \ { } = x + y
                                  // ^^^ empty effect set
```

We -- the Flix language designers -- are extremely paranoid about ensuring that
the purity of the function is _not a lie._ But surely one little lie is okay,
you say? As my mind turns to dark visions of unspeakable cosmic horror.

## Print Debugging

A sunny fall day James was sitting in front of his computer. He had just read a
blog post about the latest programming language -- Flix -- on a website called
HackerNews. Eager to try it out, he downloaded the compiler, and typed in: 

```flix
def main(): Int32 \ IO = 
    println("Hello World!");
    sum()

def sum(x: Int32, y: Int32): Int32 =
    let result = x + y;
    println("The sum of ${x} and ${y} is ${result}");
    result
```

Running the Flix compiler, James was confronted with:

```sh
❌ -- Type Error --

>> Unable to unify the effect formulas: 'IO' and 'Pure'.

6 |> def sum(x: Int32, y: Int32): Int32 = ...
```

Dismayed -- and perhaps not knowing about the cosmic horrors lurking in the
shadows -- James read a bit about effect systems and then went back to
HackerNews and wrote:

> Ever tried adding a simple print statement for debugging purposes while coding
> in effectful lang? compiler: "NNNOOOOO!!!! THIS IS AN ERROR; I WILL NEVER
> COMPILE THIS NONSENSE YOU MUST SPECIFY CONSOLE EFFECT WAAARGH" 

## Being a Programming Language Designer is Hard

The art of being a programming language designer is facing difficult trade-offs: 

- Programmers expect ultra fast compilation times but also ultra deep compiler
  optimizations. ("The compiler is slow" vs. "Don't worry, the compiler will
  optimize that.")

- Programmers expect expressive type systems, but also high quality error
  messages. ("What do you mean a skolem variable escapes???")

- Programmers expect type inference, but also high quality error messages.
  ("What do you mean you cannot unify these types???")
  
- Programmers expect escape hatches for everything. But they must never, ever
  break anything anywhere, ever. ("What do you mean turning off the fuel for the
  engines crashes the plane? I thought this was a safe aircraft!")

# Print-Debugging, Take One



<div class="hljs-deletion">

# A better solution, flix style




## Getting source and line offset

- THe debug pseudo macro, and how broken it is...


## Other Lies

Everything is printable

Getting the loc and offset is pure

</div>

# Look Ma': No Macros!

Rust has ...