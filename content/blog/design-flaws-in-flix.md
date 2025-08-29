+++
title = "Design Flaws in Flix"
description = "A reflection on design flaws made during the development of the Flix programming language"
date = 2020-01-01
[taxonomies]
tags = ["language-design", "flix"]
[extra]
authors = ["Magnus Madsen"]
+++

Inspired by the blog post [Design Flaws in Futhark](https://futhark-lang.org/blog/2019-12-18-design-flaws-in-futhark.html), I decided to take stock and reflect on some of the design flaws that I believe we made during the development of the Flix programming language. I went through old Github issues and pull requests to discover some of the challenging issues that we have been or still are struggling with. I will classify the design flaws into four categories: (i) design flaws that still plague the Flix language, (ii) design flaws that have been fixed, (iii) poor designs that were thankfully never implemented, and finally (iv) design choices where the jury is still out.

I want to emphasize that language design and implementation is a herculean task and that there are features planned for Flix which have not yet been implemented. The lack of a specific feature is not a design flaw, but rather a question of when we can get around to it.

## Design Flaws Present in Flix

The following design flaws are still present in Flix. Hopefully some day they will be fixed.

### The Switch Expression

Flix supports the `switch` expression:

```flix
switch {
    case cond1 => exp1
    case cond2 => exp2
    case cond3 => exp3
}
```

where the boolean expressions `cond1`, `cond2`, and `cond3` are evaluated from top to bottom until one of them returns true and then its associated body expression is evaluated. The idea, quite simply, is to have a control-flow structure that visually resembles an ordinary pattern match, but where there is no match value.

In hind-sight, the `switch` expression is nothing more than a glorified `if-then-else-if` construct that does not carry its own weight. It is an expenditure on the complexity and strangeness budget that offers almost no gain over using plain `if-then-else-if`. Moreover, it is error-prone, because it lacks and explicit `else` branch in case none of the conditions evaluate to true. We plan to remove it in future versions of Flix.

### String Concatenation with Plus

Like most contemporary languages, Flix uses `+` for string concatenation. While this is an uncontroversial design choice, it does not make much sense since strings are not commutative, e.g. `"abc" + "def"` is *not* the same as `"def" + "abc"`. A better alternative would be to use `++` as in Haskell. However, I believe an even better design choice would be to forgo string concatenation and instead rely entirely on string interpolation. String interpolation is a much more powerful and elegant solution to the problem of building complex strings.

## Design Flaws No Longer Present in Flix

The following design flaws have been fixed.

### Compilation of Option to Null

Flix compiles to JVM bytecode and runs on the virtual machine. An earlier version of Flix had an optimization that would take the `Option` enum:

```flix
Option[a] {
    case None,
    case Some(a)
}
```

and compile the `None` value to `null` and `Some(a)` to the underlying value of `a`. The idea was to save allocation and de-allocation of `Some` values, speeding up evaluation.

But, this screws up interoperability with Java libraries. In Java `null` might be given a special meaning that is incompatible with the meaning `None`. For example, certain Java collections cannot contain `null` and trying to put `None` into one of these would raise an unexpected exception. Consequently, Flix no longer has this optimization.

### Useless Library Functions

Flix aims to have a robust standard library that avoids some of the pitfalls of other standard libraries. We have been particularly focused on two aspects: (i) ensuring that functions and types have consistent names, e.g. `map` is named `map` for both `Option` and `List`, and (ii) to avoid partial functions, such as `List.head` and `List.tail` which are not defined for empty lists.

Yet, despite these principles, we still managed to implement some problematic functions in the library. For example, we used to have the functions `Option.isNone` and `Options.isSome`. The problem with these functions is that they are not really useful and they lead to brittle code. For example, *if* `Options.isSome` returns `true` then that information cannot be used to unwrap the option anyway. Thus such functions are not really useful.

## Function Call Syntax

Inspired by Scala, early versions of Flix did not always use parentheses to mark a function call. For example, the function:

```flix
def f: Int32 = 21
```

could be called by writing:

```flix
def g: Int32 = f + 42 // returns 63
```

The problem with this design is at least two-fold: (i) it hides when a function is applied, which is terrible in a language with side-effects, and (ii) how does one express the closure of `f`? (In Scala the answer is to write `f _`).

Today, in Flix, the code is written as:

```flix
def f(): Int32 = 21
def g: Int32 = f() + 42 // returns 63
```

which makes it clear when there is a function call.

### Infix Type Application

In Flix, a function `f` can be called with the arguments `x` and `y` in three ways: In standard prefix-style `f(x, y)`, in infix-style ``x `f` y``, and in postfix-style `x.f(y)`. The latter is also sometimes referred to as universal function call syntax. I personally feel reasonably confident that all three styles are worth supporting. The postfix-style fits well for function calls such as `a.length()` where the `length` function feels closely associated with the receiver argument. The infix-style fits well with user-defined binary operations such as ``x `lub` y`` where `lub` is the least upper bound of `x` and `y`. And of course the prefix-style is the standard way to perform a function call.

Type constructors, such as `Option` and `Result` can be thought of a special type of functions. Hence, it makes sense that their syntax should mirror function applications. For example, we can write the type applications `Option[Int32]` and `Result[Int32, Int32]` mirroring the prefix style of regular function applications. Similarly, for a while, Flix supported infix and postfix *type applications*. That is, the former could also be expressed as: `Int32.Option[]` and `Int32.Result[Int32]`, or even as ``Int32 `Result` Int32``. Thankfully, those days are gone. Striving for such uniformity in every place does not seem worth it.

### Unit Tests that Manually Construct Abstract Syntax Trees

The Flix compiler comes with more than 6,500 manually written unit tests. Each unit test is a Flix function that performs some computation, often with an expected result. The unit tests are expressed in Flix itself. For example:

```flix
@test
def testArrayStore01(): Unit = let x = [1]; x[0] = 42
```

In earlier versions of Flix such unit tests were expressed by manually constructing "small" abstract syntax tree fragments. For example, the above test would be expressed as something like:

```flix
Let(Var("x", ...), ArrayNew(...), ArrayStore(Var("x"), Int32(0), Int32(42)))
```

The problem with such tests is at least two-fold: (i) the tests turn out to be anything but small and (ii) maintenance becomes an absolute nightmare. I found that the surface syntax of Flix has remained relatively stable over time, but the abstract syntax trees have changed frequently, making maintenance of such test cases tedious and time consuming.

## Bad Ideas that were Never Implemented

These ideas were fortunately never implemented in Flix.

### The Itself Keyword

The idea was to introduce a special keyword that within a pattern match would refer to the match value. For example:

```flix
def foo(e: Exp): Exp = match e {
    // ... many lines ...
    case IfThenElse(e1, e2, e3) => itself // refers to the value of e.
}
```

The keyword `itself` refers to the value of the match expression, i.e. the value of `e`. The idea was that in very large and complicated pattern matches, with many local variables, the `itself` keyword could always be used to refer to the innermost match value. The thinking was that this would make it easier to avoid mistakes such as returning `e0` instead of `e` or the like.

The problem with this idea is at least three-fold: (i) it seems like overkill for a very specific problem, (ii) it is not worth it on the complexity and strangeness budget, and finally (iii) it is still brittle in the presence of nested pattern matches.

## Potential Design Flaws

It is debatable whether the following feature is a design flaw or not.

### Built-in Syntax for Lists, Sets, and Maps

Flix has a principle that states that the standard library should not be "blessed". That is, the standard library should be independent of the Flix compiler and language. It should just be like any other library: A collection of Flix code.

Yet, despite this principle, Flix has special syntax for Lists, Sets and Maps:

```flix
1 :: 2 :: Nil
Set#{1, 2, 3}
Map#{1 -> 2, 3 -> 4}
```

which is built-in to the language. While technically these constructs are merely syntactic sugar for `Cons`, and calls to `Set.empty`, `Set.insert`, `Map.empty` and `Map.insert` there is no getting around the fact that this is a special kind of blessing of the standard library. In particular, it is *not* possible to define your own `Foo#...` syntax for anything.
