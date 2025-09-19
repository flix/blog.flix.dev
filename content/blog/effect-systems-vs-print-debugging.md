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
In memory-safe languages, that usually means a runtime error (e.g. a
`ClassCastException`, a `TypeError: foo is not a function`, and so on). In
memory-unsafe languages, the consequences can be more dire: corrupted data,
segmentation faults, or arbitrary code execution. Nevertheless, if we are in a
memory-safe language, we might not feel too bad about lying to the type system...

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

**Automatic parallelization:** The Flix compiler, in cooperation with the Flix
Standard Library, automatically parallelizes a selected set of higher-order
functions when their arguments are pure and parallel evaluation preserves
program semantics.

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
the effects of the function are not a lie. _But surely one little white lie is
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
The art of programming language design is balancing contradictory requirements:
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
supporting print debugging.** The question is how?

## Print-Debugging — Attempt #1

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

However, when we run the program... Nothing is printed!

Now, the optimizer detects that the let-bound expression has no side effects and
that its variable is unused, so it removes it. Normally this is desirable, we
want the optimizer to eliminate dead code, but here it gets in our way.

It seems we are stuck. It seems there are two paths forward:

- We could try to equip the optimizer with knowledge of print debugging
  statements. In that case, we would track these "effects-that-are-not-effects"
  and avoid treating them as pure expressions. The problem with this approach is
  that it would have to handle the entire language—e.g., lambda expressions,
  higher-order functions, and polymorphism. In effect (no pun intended), we
  would essentially be re-implementing an ad hoc effect system inside the
  optimizer.

- We could decide to _disable_ the optimizer during development. The problem
  with that is threefold: (a) it would cause a massive slowdown in runtime
  performance, (b) somewhat surprisingly, it would also make the Flix compiler
  itself run _slower_, since dead code elimination and other optimizations
  actually speed up the backend, and (c) it would be fertile ground for compiler
  bugs, because instead of one battle-tested compiler pipeline, there would be two
  pipelines that must agree on program semantics.

Neither option is really palatable. 

## Print-Debugging — Attempt #2

What we need is a better lie: one with a different set of trade-offs.

We introduce a `Debug` effect and use it for `dprintln`:

```flix
eff Debug { /* empty -- marker effect */ }

mod Debug {
    pub def dprintln(x: a): Unit \ Debug with ToString[a] = ...
}
```

We no longer lie about `dprintln`. Calling it now has the `Debug` effect.

We can use it to debug our `sum` function from earlier:

```flix
def sum(x: Int32, y: Int32): Int32 =
    let result = x + y;
    Debug.dprintln("The sum of ${x} and ${y} is ${result}");
    result
```

The implementation of `sum` is a let-expression whose body is a
statement-expression. Because of the call to `dprintln`, the inferred effect of
both is `Debug`.

We are now back to the original problem: The `Debug` effect is incompatible with
the declared type and effect signature of `sum` (i.e., `sum` having the empty
effect set). However, instead of changing the signature of `dprintln` or `sum`,
**we will change the _effect system_ to allow the absence of the `Debug`
effect**. 

When a programmer writes a type and effect signature like: 

```flix
def downloadUrl(x: Int32): Unit \ {FileWrite, Http} = exp
```

We first check if `exp` can be type-checked with the signature: 

`Int32 -> Unit \ {FileWrite, Http}`

 If it cannot, we retry with the signature:
 
`Int32 -> Unit \ {FileWrite, Http} + Debug`

If that works, we consider the function well-typed, but crucially, we do _not_
update the signature of `downloadUrl`. Consequently, everywhere `downloadUrl` is
used, it is still typed as if it only has the `FileWrite` and `Http` effects. 

The advantages of this implementation are:
- We can use `dprintln` anywhere in a function and it just works.
- We can add `dprintln` anywhere without having to change the signature of the
  function nor the signatures of any callers. 
- We can be sure that the optimizer will leave our `dprintln` calls intact. 

There are two minor downsides. First, adding a `dprintln` marks an expression as
impure, effectively disabling the optimizer for that expression and its parent
expressions. Still, this is far less invasive than disabling the optimizer for
the entire program. Second, because the `Debug` effect is hidden from the
function’s signature, calls to that function inside other functions might be
moved or even eliminated. On the bright side, this ensures that a `dprintln`
only prints if the function is actually called!

**Development vs. Production Mode.** We don’t want published packages to (a) lie
to the type and effect system, or (b) contain print debugging statements. Hence,
when the compiler is run in production mode, we disable the lie that allows the
implicit `Debug` effect. As a result, using `dprintln` in production mode causes
a compilation error. 

## Addendum: Look Ma: No Macros!

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
