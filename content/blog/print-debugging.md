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

A sunny fall day Jim was sitting in front of his computer. He had just read a
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

Running the Flix compiler, Jim was confronted with:

```sh
❌ -- Type Error --

>> Unable to unify the effect formulas: 'IO' and 'Pure'.

6 |> def sum(x: Int32, y: Int32): Int32 = ...
```

Dismayed -- and perhaps not knowing about the cosmic horrors lurking in the
shadows -- Jim read a bit about effect systems and then went back to
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

We may be academics, but we are trying to build a real programming language, so
we have to be receptive to feedback. So in that spirit, let us try to support
print debugging: 

# Print-Debugging - Attempt #1

We introduce a special `dprintln` function: 

```flix
mod Debug {
    pub def dprintln(x: a): Unit with ToString[a] =
        unchecked_cast(println(x) as _ \ {}) 
}
```

We use an `unchecked_cast` to ignore the `IO` effect of the `println` function.
We also accept any argument of type `a` as long as it has a `ToString[a]`
instance. 

Unfortunately, our function does not work so well. If we write:

```flix
def sum(x: Int32, y: Int32): Int32 =
    let result = x + y;
    Debug.dprintln("The sum of ${x} and ${y} is ${result}");
    result
```

The Flix compiler rejects our program with the error:

```sh
❌ -- Redundancy Error --

>> Useless expression: It has no side-effect(s) and its result is discarded.

11 |         Debug.dprintln("The sum of ${x} and ${y} is ${result}");
             ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
             useless expression.
```

The Flix compiler has -- quite correctly -- identified that the `dprintln`
expression is useless. It has no side-effect and its result is unused, hence it
can be removed. Under normal circumstances this is definitely a bug, but here it
is our intention. We can try to get around the problem with another trick:

```flix
def sum(x: Int32, y: Int32): Int32 =
    let result = x + y;
    let _ = Debug.dprintln("The sum of ${x} and ${y} is ${result}");
    result
```

Using a let-binding with a wildcard name allows the program to pass the
redundancy checker. Now the program compiles. We run and then:

Nothing.

The program does not print anything. The problem is that the whole-program
optimizer has identifed that the expression `dprintln` is unused and can be
removed. This is good! We want to optimizer to remove dead code, especially in
combination with inlining. But its now what we wanted here. 

At this point, we might think, can we not have the optimizer know about `dprintln` and treat it 
specially? Unfortunately this does not work either. Imagine if we have:

```flix
def sum(x: Int32, y: Int32): Int32 =
    def foo() = { Debug.dprintln("The sum of ${x} and ${y} is ${result}")}; 
    foo();
    x + y
```

Now we have to track `dprintln` through function calls. In other words, we would have to 
reimplement part of the effect system, just purely and adhoc. This does not work.

Back to the drawing board.

# Print-Debugging - Fixed

We are kind of stuck. We want to lie to the effect system, but in doing so, we
wreck havoc on the entire system. We need a better lie. Or rather a more
pragmatic approach. 

We have been going against the grain of type and effect system by lying about
the purity of `dprintln`. Well, what if we did not? We could let `dprintln` have
a new special effect -- call it `Debug`. In our function we let the `Debug`
effect propagate. 

```flix
def sum(x: Int32, y: Int32): Int32 =
    let result = x + y;
    Debug.dprintln("The sum of ${x} and ${y} is ${result}");
    result
```

What happens now is that the expression, the statement-expression, and
ultimately the let-binding all get the `Debug` effect. In fact, the type and
effect system will precisely track the effect through the entire function body
precisely, including through function calls, pipelines, closures, etc. etc. 

Now in some sense we are back where we started, because now we get an error 
that our type and effect signature of `sum` lacks the `Debug` effect. But now we
attack the problem from a different angle. We allow the expression body of a 
function to have the `Debug` effect even if it does not appear in its signature!

The upshot is that we can use `dprintln` anywhere inside a function and it will
work correctly. In particular, we can be sure that the compiler will neither move
the expression that prints nor eliminates it. 

However, we have not fully solved the problem. By allowing a function to have
the `Debug` effect internally, but not externally, it means that a call to a
pure function could still be moved or omitted. But in some sense this is OK.
We debugging we want to debug the program as it will actually execute.
If an entire function call can be eliminated then we would not expect it to print. 

The last detail that remains is that a lying type and effect system is not great.
Hence, while we allow functions "omit" the `Debug` effect, we only allow this
when a program is compiled in development mode. Under production mode, 
the `Debug` effect cannot be hidden. It must be surfaced. Thus this pragmatic
proposal has many desirable properties:

- We can use `dprintln` for print debugging without too much thpught. It will just work out of the box.
- We do have to remember that if an entire function is pure then it may be moved or eliminated by the opti,mizer,
but this refects runtime beahavior anyway.
- Finally, in release mode the type and effect system does not lie.

# Look Ma': No Macros!

Rust has a beautiful [`dbg!` macro](https://doc.rust-lang.org/std/macro.dbg.html). It works something like this:

```rust
let a = 2;
let b = dbg!(a * 2) + 1;
//      ^-- prints: [src/main.rs:2:9] a * 2 = 4
assert_eq!(b, 5);
```

The macro has access to the syntax tree, so not only can it print the file name,
the line, and the column offset, it can also print its expression. Beautiful!
Flix does not (yet?) have macros. And in any case, we would not add them for a
single feature like this. 

Nevertheless, we can get some of this functionality. Introducing **debug string
interpolators**. In all its simplicitly, we can write:

```flix
use Debug.dprintln

def main(): Unit \ IO = 
    let result = sum(123, 456);
    println("The sum is: ${result}")

def sum(x: Int32, y: Int32): Int32 = 
    dprintln(d"x = ${x}, y = ${y}");
    x + y
```

Notice the string literal: `d"x = ${x}, y = ${y}"`. Running this program prints:

```sh
[/Users/.../flix/Main.flix:8] x = 123, y = 456                         
The sum is: 579
```

We get the file name and line number for the small cost of a single `d`. 

Until next time, happy hacking.
