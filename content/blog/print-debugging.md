+++
title = "Effect Systems vs Print Debugging: A Pragmatic Solution"
description = "A discussion of how the Flix type and effect system supports print-debugging."
date = 2025-09-15
authors = ["Magnus Madsen"]

[taxonomies]
tags = ["effects", "language-design", "flix"]
+++

> **"Every lie we tell incurs a debt to the truth. Sooner or later, that debt is paid."**

— Valery Legasov (*Jared Harris, Chernobyl 2019*)

Lying to a **type system works** the same way: the truth eventually comes due.
In memory-safe languages, that usually means an runtime error (e.g. a
`ClassCastException`, a `TypeError: foo is not a function`, and so on). In
memory-unsafe languages, the consequences can be more dire: corrupted data,
segmentation faults, or arbitrary code execution. Nevertheless, if we are in a
memory-safe language, we might not feel to bad about lying to the type system...

But what happens when you lie to the **effect system**? Nothing good.

To understand why, let us examine how the Flix compiler leverages the effect system:

**Dead code elimination:** Flix uses the effect system to identify expressions,
statements, and let-bindings that have no side effects and whose results are
unused. The compiler removes such code, improving performance and reducing
binary size.

**Inlining and value propagation:** Flix also uses the effect system to
determine which let-bindings can be safely inlined without changing program
semantics. This enables constant folding and closure elimination, further
improving performance.

**Separating control-pure from control-impure code:** Flix uses effect tracking
to distinguish code that may trigger effects and handlers from purely
computational code. Control-pure code is compiled without capturing the
delimited continuation, while control-impure code includes the machinery
required to reify the stack.

These are scary program transformations!

Hence, when a Flix programmer writes a function:

```flix
def add(x: Int32, y: Int32): Int32 \ { } = x + y
                                  // ^^^ empty effect set
```

We — the Flix language designers — are downright paranoid about ensuring that
the effects of the function is not a lie. _But surely one little white lie is
okay, you suggest, as you carelessly add that `unchecked_cast` to your program_,
while I look on with dark visions of unspeakable cosmic horror. To be continued —

## Print Debugging

One beautiful autumn afternoon, Jim was sitting in front of his computer.
Outside, the leaves were turning brilliant shades of orange, while inside, a
freshly brewed cup of coffee sat beside him. He had just finished reading a blog
post on HackerNews about a new programming language with a type and effect
system: Flix.

Intrigued, he downloaded the compiler and typed:

```flix
def main(): Int32 \ IO = 
    println("Hello World!");
    sum(123, 456)

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

Dismayed, Jim poked around a bit but couldn’t get the program to work.
Frustrated, he returned to HackerNews and posted a comment:

> Ever tried adding a simple print statement for debugging purposes while coding
> in effectful lang? compiler: "NNNOOOO!!!! THIS IS AN ERROR; I WILL NEVER
> COMPILE THIS NONSENSE YOU MUST SPECIFY THE `CONSOLE` EFFECT WAAARGH" 

## Being a Programming Language Designer is Hard

Continued— <br/>
The art programming language design is to balance contradictory requirements:
- Programmers expect lightning-fast compilation, but also deep, aggressive
  compiler optimizations. ("the compiler is too slow!" vs. "surely the compiler
  will optimize that away!")
- Programmers want expressive type systems, but also intuitive and helpful error
  messages. ("What do you mean a skolem variable escapes its scope???")
- Programmers want type inference, but also simple type error messages ("What do
  you mean you can't unify these types?")
- Programmers want escape hatches for everything, but nothing must ever break.
  ("What do you mean turning off the fuel for the engines crashes the plane? I
  thought you said this was a safe airplane?!")

Returning to earth: we may be academics, but **we are trying to build a real
programming language. That means listening to our users—and that means
supporting print debugging.** The question is how??

# Print-Debugging — Attempt #1

Consider if we introduce a special `dprintln` function:

```flix
mod Debug {
    pub def dprintln(x: a): Unit with ToString[a] =
        unchecked_cast(println(x) as _ \ {}) 
}
```

Here we use an `unchecked_cast` to discard the `IO` effect of `println`. That
is, we _lie_ to the effect system. We allow `dprintln` to accept any argument of
type `a` provided that there is a `ToString` instance for it. 

While our special `dprintln` function type and effect checks, it does not work
well.

If we attempt to use it as follows:

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

The compiler _correctly_ reports that `dprintln` is a useless expression: it has
no observable effects and its result is ignored. This redundancy check is
normally helpful for catching bugs, but in this case it prevents our use of
`dprintln`.

We can try to work around this check with a small trick:

```flix
def sum(x: Int32, y: Int32): Int32 =
    let result = x + y;
    let _ = Debug.dprintln("The sum of ${x} and ${y} is ${result}");
    result
```

By introducing a let binding with a wildcard name, the redundancy checker is
satisfied and the program now compiles.

However, when we run the porgram... Nothing is printed!

The optimizer detects that the let-bound expression has no side effects and that
its variable is unused, so it removes it. Normally this is desirable, we want
the optimizer to eliminate dead code, but here it gets in our way.

At this point, we might think, can we not have the optimizer know about
`dprintln` and treat it specially? Unfortunately this does not work either.
Imagine if we have:

```flix
def sum(x: Int32, y: Int32): Int32 =
    def foo() = { Debug.dprintln("The sum of ${x} and ${y} is ${result}")}; 
    foo();
    x + y
```

Now we have to track `dprintln` through function calls. In other words, we would have to 
reimplement part of the effect system, just purely and adhoc. This does not work.

Back to the drawing board.

# Print-Debugging — Attempt #2

We are kind of stuck. We want to lie to the effect system, but in doing so, we
wreck havoc on the entire system. We need a better lie. Or rather a more
pragmatic approach. 

We have been going against the grain of type and effect system by lying about
the purity of `dprintln`. Well, what if we did not? We could let `dprintln` have
a new special effect — call it `Debug`. In our function we let the `Debug`
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
When debugging we want to debug the program as it will actually execute.
If an entire function call can be eliminated then we would not expect it to print. 

The last detail that remains is that a lying type and effect system is not great.
Hence, while we allow functions "omit" the `Debug` effect, we only allow this
when a program is compiled in development mode. Under production mode, 
the `Debug` effect cannot be hidden. It must be surfaced. Thus this pragmatic
proposal has many desirable properties:

- We can use `dprintln` for print debugging without too much thought. It will just work out of the box.
- We do have to remember that if an entire function is pure then it may be moved or eliminated by the optimizer,
but this reflects runtime behavior anyway.
- Finally, in release mode the type and effect system does not lie.

# Addendum: Look Ma: No Macros!

Rust has a beautiful [`dbg!` macro](https://doc.rust-lang.org/std/macro.dbg.html) which works like this: 

```rust
let a = 2;
let b = dbg!(a * 2) + 1;
//      ^-- prints: [src/main.rs:2:9] a * 2 = 4
assert_eq!(b, 5);
```

Since the macro has access to the syntax tree, it can print the file name, line,
column, and the original expression. Flix does not currently support macros (and
we would not introduce them solely for this purpose). However, we can achieve
part of this functionality using a **debug string interpolator**. 

For example, we can write:

```flix
use Debug.dprintln

def main(): Unit \ IO = 
    let result = sum(123, 456);
    println("The sum is: ${result}")

def sum(x: Int32, y: Int32): Int32 = 
    dprintln(d"x = ${x}, y = ${y}");
    x + y
```

Note the debug string interpolator `d"x = ${x}, y = ${y}"`. 

Running the program prints:

```sh
[Main.flix:8] x = 123, y = 456                         
The sum is: 579
```

We get the file name and line number for the small cost of a single `d`. 

Until next time, happy hacking.
