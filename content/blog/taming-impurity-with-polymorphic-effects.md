+++
title = "Taming Impurity with Polymorphic Effects"
description = "How Flix uses a type and effect system to cleanly separate pure and impure code while supporting equational reasoning"
authors = ["Magnus Madsen"]
date = 2020-05-01

[taxonomies]
tags = ["effects", "language-design", "flix"]
+++

In the blog post [Patterns of Bugs](https://www.digitalmars.com/articles/b60.html), Walter Bright,
the author of the [D programming Language](https://dlang.org/), writes about his
experience working at Boeing and their attitude towards failure:

> "[...] The best people have bad days and make mistakes, so the solution is to
> change the process so the mistakes cannot happen or cannot propagate."
> 
> "One simple example is an assembly that is bolted onto the frame with four bolts. The
> obvious bolt pattern is a rectangle. Unfortunately, a rectangle pattern can be assembled
> in two different ways, one of which is wrong. The solution is to offset one of the bolt
> holes — then the assembly can only be bolted on in one orientation. The possible
> mechanic's mistake is designed out of the system."
> 
> "[...] *Parts can only be assembled one way, the correct
> way.*"

(Emphasis mine).

Bright continues to explain that these ideas are equally applicable to software: We should
build software such that it can only be assembled correctly. In this blog post, I will
discuss how this idea can be applied to the design of a type and effect system. In
particular, I will show how the Flix programming language and, by extension, its standard
library ensure that pure and impure functions are not assembled incorrectly.

## Impure Functional Programming

A major selling point of functional programming is that it supports [equational reasoning](https://wiki.haskell.org/Equational_reasoning_examples).
Informally, equational reasoning means that we can reason about programs by replacing an
expression by another one, provided they're both equal. For example, we can substitute
variables with the expressions they are bound to.

For example, if we have the program fragment:

```flix
let x = 1 + 2;
    (x, x)
```

We can substitute for `x` and understand this program as:

```flix
(1 + 2, 1 + 2)
```

Unfortunately, in the presence of side-effects, such reasoning breaks down.

For example, the program fragment:

```flix
let x = Console.printLine("Hello World");
    (x, x)
```

is *not* equivalent to the program:

```flix
(Console.printLine("Hello World"), Console.printLine("Hello World"))
```

Most contemporary functional programming languages, including Clojure, OCaml, and Scala,
forgo equational reasoning by allow arbitrary side-effects inside functions. To be clear,
it is still common to write purely functional programs in these languages and to reason
about them using equational reasoning. The major concern is that there is no language
support to guarantee when such reasoning is valid. Haskell is the only major programming
language that guarantees equational reasoning at the cost of a total and absolute ban on
side-effects.

Flix aims to walk on the middle of the road: We want to support equational reasoning with
strong guarantees while still allowing side-effects. Our solution is a type and effect
system that cleanly separates pure and impure code. The idea of using an effect system
to separate pure and impure code is old, but our implementation, which supports type
inference and polymorphism, is new.

## Pure and Impure Functions

Flix functions are pure by default. We can write a pure function:

```flix
def inc(x: Int): Int = x + 1
```

If we want to be explicit, but non-idiomatic, we can write:

```flix
def inc(x: Int): Int \ {} = x + 1
```

where `\ {}` specifies that the `inc` function is pure.

We can also write an impure function:

```flix
def sayHello(): Unit \ IO = Console.printLine("Hello World!")
```

where `\ IO` specifies that the `sayHello` function is impure.

The Flix type and effect system is *sound*, hence if we forget the `\ IO` annotation
on the `sayHello` function, the compiler will emit a type (or rather effect) error.

The type and effect system cleanly separates pure and impure code. If an expression is pure
then it always evaluates to the same value and it cannot have side-effects. This is part
of what makes Flix functional-first: We can trust that pure functions behave like
mathematical functions.

We have already seen that printing to the screen is impure. Other sources of impurity are
mutation of memory (e.g. writing to main memory, writing to the disk, writing to the
network, etc.). Reading from mutable memory is also impure because there is no guarantee
that we will get the same value if we read the same location twice.

In Flix, the following operations are impure:

- Any use of channels (creating, sending, receiving, or selecting).
- Any use of references (creating, accessing, or updating).
- Any use of arrays (creating, accessing, updating, or slicing).
- Any interaction with the Java world.

## Higher-Order Functions

We can use the type and effect system to restrict the purity (or impurity) of function
arguments that are passed to higher-order functions. This is useful for at least two
reasons: (i) it prevents leaky abstractions where the caller can observe implementation
details of the callee, and (ii) it can help avoid bugs in the sense of Walter Bright's
"Parts can only be assembled one way, the correct way."

We will now look at several examples of how type signatures can control purity or impurity.

We can enforce that the predicate `f` passed
to `Set.exists` is *pure*:

```flix
def exists(f: a -> Bool, xs: Set[a]): Bool = ...
```

The signature `f: a -> Bool` denotes a pure function
from `a` to `Bool`. Passing an impure function
to `exists` is a compile-time type error. We want to enforce
that `f` is pure because the contract for `exists` makes no guarantees
about how `f` is called. The implementation of `exists` may
call `f` on the elements in `xs` in any order and any number of times.
This requirement is *beneficial* because its allows freedom in the implementation
of `Set`, including in the choice of the underlying data structure and in the
implementation of its operations. For example, we can implement sets using search trees or
with hash tables, and we can perform existential queries in parallel using
fork-join. If `f` was impure such implementation details would leak and be
observable by the client. *Functions can only be assembled one way, the correct way.*

We can enforce that the function `f` passed to the
function `List.foreach` is *impure*:

```flix
def foreach(f: a -> Unit \ IO, xs: List[a]): Unit \ IO = ...
```

The signature `f: a -> Unit \ IO` denotes an impure function
from `b` to `Unit`. Passing a pure function to `foreach` is
a compile-time type error. Given that `f` is impure and `f` is called
within `foreach`, it is itself impure. We enforce that
the `f` function is impure because it is pointless to apply
a *pure* function with a `Unit` return type to every element of a list. *Functions
can only be assembled one way, the correct way.*

We can enforce that event listeners are impure:

```flix
def onMouseDn(f: MouseEvent -> Unit \ IO): Unit \ IO = ...
def onMouseUp(f: MouseEvent -> Unit \ IO): Unit \ IO = ...
```

Event listeners are always executed for their side-effect: it would be pointless to register
a pure function as an event listener.

We can enforce that assertion and logging facilities are given pure functions:

```flix
def assert(f: Unit -> Bool): Unit = ...
def log(f: Unit -> String , l: LogLevel): Unit = ...
```

We want to support assertions and log statements that can be enabled and disabled at
run-time. For efficiency, it is critical that when assertions or logging is disabled, we do
not perform any computations that are redundant. We can achieve this by having the assert
and log functions take callbacks that are only invoked when required. A critical property of
these functions is that they must not influence the execution of the program. Otherwise, we
risk situations where enabling or disabling assertions or logging may impact the presence or
absence of a buggy execution. We can prevent such situations by requiring that the functions
passed to `assert` and `log` are pure.

We can enforce that user-defined equality functions are pure. We want purity because the
programmer should not make any assumptions about how such functions are used. Moreover, most
collections (e.g. sets and maps) require that equality does not change over time to maintain
internal data structure invariants. Similar considerations apply to hash and comparator
functions.

In the same spirit, we can enforce that one-shot comparator functions are pure:

```flix
def minBy(f: a -> b, l: List[a]): Option[a] = ...
def maxBy(f: a -> b, l: List[a]): Option[a] = ...
def sortBy(f: a -> Int32, l: List[a]): List[a] = ...
def groupBy(f: a -> k, l: List[a]): Map[k, List[a]] = ...
```

We can enforce that the `next` function passed
to `List.unfoldWithIter` is impure:

```flix
def unfoldWithIter(next: Unit -> Option[a] \ IO): List[a] \ IO
```

The unfoldWithIter function is a variant of the `unfoldWith` function where each
invocation of `next` changes some mutable state until the unfold completes. For
example, `unfoldWithIter` is frequently used to convert Java-style iterators into
lists. We want to enforce that `next` is impure because otherwise it is pointless
to use `unfoldWithIter`. If `next` is pure then it must always either
(i) return `None` which results in the empty list or (ii)
return `Some(v)` for a value `v` which would result in an infinite
execution.

We can use purity to reject useless statement expressions. For example, the program:

```flix
def main(): Int =
    List.map(x -> x + 1, 1 :: 2 :: Nil);
    123
```

is rejected with the compiler error:

```
-- Redundancy Error ------------------ foo.flix

>> Useless expression: It has no side-effect(s) and its result is discarded.

   2 | List.map(x -> x + 1, 1 :: 2 :: Nil);
       ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
       useless expression.
```

Notice that the `List.map(...)` expression is pure because the function `x
-> x + 1` is pure.

## Polymorphic Effects

Flix supports effect polymorphism which means that the effect of a higher-order function can
depend on the effects of its function arguments.

For example, here is the type signature of `List.map`:

```flix
def map(f: a -> b \ ef, xs: List[a]): List[b] \ ef = ...
```

The syntax `f: a -> b \ ef` denotes a function
from `a` to `b` with latent effect `ef`. The signature of
the `map` function captures that its
effect `ef` depends on the effect of its argument `f`.
That is, if `map` is called with a pure function then its evaluation is pure,
whereas if it is called with an impure function then its evaluation is impure. The effect
signature is *conservative* (i.e. over-approximate). That is,
the `map` function is considered impure even in the special case when the list is
empty and its execution is actually pure.

The type and effect system can express combinations of effects using boolean operations.
We can, for example, express that forward function composition `>>` is pure
if both its arguments are pure:

```flix
def >>(f: a -> b \ ef1, g: b -> c \ ef2): a -> c \ { ef1, ef2 } = x -> g(f(x))
```

Here the function `f` has effect `ef1` and `g` has
effect `ef2`. The returned function has effect `ef1 and ef2`, i.e. for it
to be pure both `ef1` and `ef2` must be pure. Otherwise it is impure.

## Type Equivalences

Let us take a short detour.

In a purely functional programming language, such as Haskell, mapping two
functions `f` and `g` over a list `xs` is equivalent to
mapping their composition over the list. That is:

```flix
map(f, map(g, xs)) == map(f >> g, xs)
```

We can use such an equation to (automatically) rewrite the program to one that executes more
efficiently because the code on the right only traverses the list once and avoids
allocation of an intermediate list. Haskell already has support for such [rewrite rules](https://wiki.haskell.org/GHC/Using_rules) built into the language.

It would be desirable if we could express the same rewrite rules for programming languages
such as Clojure, OCaml, and Scala. Unfortunately, identities - such as the above - do not
hold in the presence of side-effects. For example, the program:

```flix
let f = x -> {Console.printLine(x); x};
let g = y -> {Console.printLine(y); y};
List.map(f, List.map(g, 1 :: 2 :: Nil))
```

prints `1, 2, 3, 1, 2, 3`. But, if we apply the rewrite rule, the transformed
program now prints `1, 1, 2, 2, 3, 3`! In the presence of side-effects we cannot
readily apply such rewrite rules.

We can use the Flix type and effect to ensure that a rewrite rule like the above is only
applied when both `f` and `g` are pure!

We can, in fact, go even further. If *at most
one* of `f` and `g` is impure then it is still safe to apply
the above rewrite rule. Furthermore, the Flix type and effect system is sufficiently
expressive to capture such a requirement!

We can distill the essence of this point into the type signature:

```flix
def mapCompose(f: a -> b \ e1, g: b -> c \ {(not e1) or e2}, xs: List[a]): ... = ...
```

It is not important exactly what `mapCompose` does (or even if it makes sense).
What is important is that it has a function signature that requires two function
arguments `f` and `g` of which at most one may be impure.

To understand why, let us look closely at the signature of `mapCompose`:

```flix
def mapCompose(f: a -> b \ e1, g: b -> c \ {(not e1) or e2}, xs: List[a]): ... = ...
```

- If `e1 = T` (i.e. `f` is pure) then `(not e1) or e2 = F or e2 = e2`. In other words, `g` may be pure or impure. Its purity is not constrained by the type signature.
- If, on the other hand, `e1 = F` (i.e. `f` is impure) then `(not e1) or e2 = T or e2 = T `. In other words, `g` *must* be pure, otherwise there is a type error.

If you think about it, the above is equivalent to the requirement that at most one
of `f` and `g` may be impure.

Without going into detail, an interesting aspect of the type and effect system is
that we might as well have given `mapCompose` the equivalent (equi-most general)
type signature:

```flix
def mapCompose(f: a -> b \ {(not e1) or e2}, g: b -> c \ e1, xs: List[a]): ... = ...
```

where the effects of `f` and `g` are swapped.

## Benign Impurity

It is not uncommon for functions to be internally impure but observationally pure.
That is, a function may use mutation and perform side-effects without it being observable
by the external world. We say that such side-effects are *benign*. Fortunately, we can
still treat such functions as pure with an explicit *effect cast*.

For example, we can call a Java method (which may have arbitrary side-effects) but
explicitly mark it as pure with an effect cast:

```flix
///
/// Returns the character at position `i` in the string `s`.
///
def charAt(i: Int, s: String): Char =
    import java.lang.String.charAt(Int32);
    s.charAt(i) as \ {}
```

We know that `java.lang.String.charAt` has is pure hence the cast is safe.

An effect cast, like an ordinary cast, must be used with care. A cast is a mechanism
that allows the programmer to subvert the type (and effect) system. It is the
responsibility of the programmer to ensure that the cast is safe. Unlike type casts, an
effect cast cannot be checked at run-time with the consequence that an unsound effect cast
may silently lead to undefined behavior.

Here is an example of a pure function that is implemented internally using mutation:

```flix
///
/// Strip every indented line in string `s` by `n` spaces. `n` must be greater than `0`.
/// Note, tabs are counted as a single space.
///
/// [...]
///
def stripIndent(n: Int32, s: String): String =
        if (n <= 0 or length(s) == 0)
            s
        else
            stripIndentHelper(n, s) as \ {}
        
///
/// Helper function for `stripIndent`.
///
def stripIndentHelper(n: Int32, s: String): String \ IO =
    let sb = StringBuilder.new();
    let limit = Int32.min(n, length(s));
    let step = s1 -> {
        let line = stripIndentDropWhiteSpace(s1, limit, 0);
        StringBuilder.appendLine!(sb, line)
    };
    List.foreach(step, lines(s));
    StringBuilder.toString(sb)
```

Internally, `stripIndentHelper` uses a mutable string builder.

## Type Inference and Boolean Unification

The Flix type and effect system supports inference. Explicit type annotations are never
required locally within a function. As a design choice, we do require type signatures for
top-level definitions. Within a function, the programmer never has to worry about pure and
impure expressions; the compiler automatically infers whether an expression is pure, impure,
or effect polymorphic. The programmer only has to ensure that the declared type and effect
matches the type and effect of the function body.

The details of the type and effect system are the subject of a forthcoming research paper
and will be made available in due time.

## Closing Thoughts

The Flix type and effect system separates pure and impure code. The upshot is that a
functional programmer can trust that a pure function behaves like a mathematical function:
it returns the same result when given the same arguments. At the same time, we are still
allowed to write parts of the program in an impure, imperative style. Effect polymorphism
ensures that both pure and impure code can be used with higher-order functions.

We can also use effects to control when higher-order functions require pure (or impure)
functions. We have seen several examples of such use cases, e.g. requiring
that `Set.count` takes a pure function or
that `List.unfoldWithIter` takes an impure function. Together, these restrictions
ensure that functions can only be assembled in one way, the correct way.

Until next time, happy hacking.
