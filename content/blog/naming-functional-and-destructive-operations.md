+++
title = "Naming Functional and Destructive Operations"
description = "A discussion on naming consistency when a programming language supports both functional and destructive operations"
date = 2020-04-01
authors = ["Magnus Madsen"]

[taxonomies]
tags = ["naming", "language-design", "flix"]
+++

It has been said that there are only two hard problems in computer science: (i) naming, (ii) cache invalidation, and (iii) off-by-one errors. In this blog post, I will explain a *name consistency issue* that arises when a programming language wants to support both functional and destructive operations. (A functional operation always returns new data, whereas a destructive operation mutates existing data. For example, functionally reversing an array returns a *new* array with its elements reversed, whereas destructively reversing an array mutates the array in place.)

Flix supports functional, imperative, and logic programming. Flix is intended to be *functional-first* which simply means that if there is a trade-off between having better functional- or imperative programming support, we tend to favor design choices that support functional programming. For example, the Flix effect system separates pure and impure functions mostly to the benefit of functional programming.

Flix, being imperative, wants to support mutable data structures such as arrays, mutable sets and maps. We have recently added support for all three. But let us for a moment consider a simpler data structure: the humble list.

We can `map` a function `f: a -> b` over a list `l` to obtain a new list of type `List[b]`:

```flix
def map(f: a -> b \ ef, l: List[a]): List[b] \ ef
```

(Here the `ef` denotes that the function is *effect polymorphic*, but that is for another day.)

We can also `map` a function over an option:

```flix
def map(f: a -> b \ ef, o: Option[a]): Option[b] \ ef
```

We can also `map` a function over an array:

```flix
def map(f: a -> b \ ef, a: Array[a]): Array[b] \ IO
```

This is good news: we can program with arrays in a functional-style. Mapping over an array is certainly meaningful and useful. It might even be faster than mapping over a list! Nevertheless, the main reason for having arrays (and mutable sets and maps) is to program with them imperatively. We *want* to have operations that *mutate* their data.

We want an operation that applies a function to every element of an array *changing it in place*. **What should such an operation be called?** We cannot name it `map` because that name is already taken by the functional version. Let us simply call it `mapInPlace` for now:

```flix
def mapInPlace(f: a -> a \ ef, a: Array[a]): Unit \ IO
```

The signature of `mapInPlace` is different from the signature of `map` in two important ways:

- The function returns `Unit` instead of returning an array.
- The function takes an argument of type `a -> a` rather than a function of type `a -> b`.

The latter is required because the type of an array is fixed. An array of bytes cannot be replaced by an array of strings. Consequently, `mapInPlace` must take a less generic function of type `a -> a`.

We have seen that it is useful to have both functional and destructive functions such as `map` and `mapInPlace`, but what should such functions be called? Are they sufficiently similar that they should share similar names? What should be the general rule for naming functional operations and their counter-part destructive operations?

To answer these questions, we surveyed the Flix standard library to understand what names are currently being used. The table below shows a small cross section of the results:

| Functional Operation | Destructive Equivalent |
|---------------------|------------------------|
| Array.map | Array.mapInPlace |
| Array.reverse | Array.reverseInPlace |
| *missing* | Array.sortByInPlace |
| Set.insert | not relevant – immutable |
| Set.union | not relevant – immutable |
| *missing* | MutSet.add |
| *missing* | MutSet.addAll |
| MutSet.map | MutSet.transform |

The table exposes the lack of any established naming convention. Let us consider some of the many inconsistencies: For arrays, the functional and destructive operations are named `Array.map` and `Array.mapInPlace`, but for mutable sets the operations are named `MutSet.map` and `MutSet.transform`. As another example, for immutable sets, we have `Set.insert` and `Set.union`, but these functional operations are missing on the mutable set. Moreover, the mutable version of `Set.union` is called `Set.addAll`. Finally, `Array.sortByInPlace`, what a name!

## Exploring the Design Space

With these examples in mind, we tried to come up with a principled approach to naming. Our exploration ended up with the following options:

### Option I: Distinct names

**Proposal:** We give distinct names to functional and destructive operations. For example, we will have `Array.map` and `Array.transform`, and `MutSet.union` and `MutSet.addAll`. We reserve the most common names (e.g. `map`) for the functional operations.

**Discussion:** With distinct names there is little room for confusion, but it may be difficult to come up with meaningful names. For example, what should the destructive version of `reverse` be called?

### Option II: Use similar names but with a prefix or suffix

**Proposal:** We reuse names between functional and destructive operations. To distinguish operations, we add a prefix or suffix to the name. For example, `reverseInPlace`, `inPlaceReverse`, `reverseMut`, or similar.

**Discussion:** The advantage of this approach is that names are immediately consistent. The disadvantages are that: (i) it may be difficult to come up with a good prefix or suffix word, (ii) some users may dislike the chosen prefix or suffix, and (iii) it may be confusing that the signatures for two similarly named operations differ not only in the return type, but also in the polymorphism of the arguments.

### Option III: Use similar names but with a prefix or suffix symbol

**Proposal:** Similar to the previous proposal, but instead we use a symbol. For example: `reverse!`, `reverse*`, or the like.

**Discussion:** The same advantages and disadvantages of the previous proposal, but with the difference that using a symbol may be more or less appealing to programmers.

### Option IV: Use namespaces

**Proposal:** We place all functional operations into one namespace and all destructive operations into another. For example, we might have `Array.reverse` and `MutArray.reverse`.

**Discussion:** While this solution appears simple, it has two downsides: (i) we now have multiple functions named `reverse` with different semantics and (ii) we get a plethora of namespaces for data structures that exist in both immutable and mutable variants. For example, we might end up with `Set.map` (functional map on an immutable set), `MutSet.Mut.map` (destructive map on a mutable set), and `MutSet.Imm.map` (functional map on a mutable set).

### Option V: The Python approach: sort vs. sorted

**Proposal:** In Python the `sorted` operation functionally returns a new sorted list whereas the `sort` operation destructively sorts a list in place. We use the same scheme for `reverse` and `reversed`, `map` and `mapped`, and so forth.

**Discussion:** An internet search reveals that many programmers are puzzled by the Python naming scheme. Another disadvantage is that the common functional names, e.g. `map` and `reverse` would be reserved for destructive operations (unless we adopt the *opposite* convention of Python).

### Option VI: Drop functional operations for mutable data

**Proposal:** We drop support for functional operations on mutable data structures. If the user wants to map a function over an array, mutable set, or mutable map he or she must first convert it to an immutable data structure. For example, to functionally reverse an array one would write `a.toList().reverse().toArray()`.

**Discussion:** The "stick your head in the sand approach". The programmer must explicitly convert back and forth between immutable and mutable data structures. While such an approach side-steps the naming issue, it is verbose and slow (because we have to copy collections back and forth). Deliberately leaving functionality out of the standard library does not mean that programmers will not miss it; instead we are just passing the problem onto them.

## The Principles

We debated these options and slept on them for a few nights before we ultimately ended up with the following hybrid principles:

### Library: Mutable Data is Functional Data

In Flix, every mutable data structure supports functional operations. For example, mutable collections, such as `Array` and `MutSet` support the `map` operation. Flix, being functional-first, reserves functional names for functional operations. Across the standard library `map` has the same name and the same type signature.

### Library: Destructive Operations are Marked with '!'

In Flix, every destructive operation is suffixed with an exclamation point. For example, `Array.reverse(a)` returns a new array with the elements of `a` in reverse order, whereas `Array.reverse!(a)` destructively re-orders the elements of `a`. Note: This principle applies to destructive operations that operate on data structures, not to impure functions in general, e.g. `Console.printLine`.

As a side-note: Scheme has used `!` to indicate destructive operations for a long-time.

### Library: Consistent Names of Functional and Destructive Operations

In Flix, functional and destructive operations that share (i) similar behavior and (ii) similar type signatures share similar names. For example, `Array.reverse` and `Array.reverse!` share the same name. On the other hand, `Array.transform!` is called `transform!` and not `map!` because its type signature is dissimilar to map (i.e. map works on functions of type `a -> b`, but transform requires functions of type `a -> a`.)

We are in the process of refactoring the standard library to satisfy these new principles.

Going forward, we are sensitive to at least four potential issues:

- Whether users come to like the aesthetics of names that end in exclamation point.
- If there is confusion about when exclamation points should be part of a name.
- If there is confusion about when two operations should share the same name.
- That Rust uses exclamation points for macro applications.

As Flix continues to mature, we will keep an eye on these issues.

Until next time, happy hacking.
