+++
title = "Improved Error Messages"
description = "TODO"
date = 2026-02-01
authors = ["Magnus Madsen"]

[taxonomies]
tags = ["language-design", "flix"]
+++

Inspired by Elm's
[Compiler Errors for Humans](https://elm-lang.org/news/compiler-errors-for-humans) and
[Compilers as Assistants](https://elm-lang.org/news/compilers-as-assistants),
we recently took the time to revisit all the error messages in the Flix compiler.

Here is what you can look forward to in the next version of the Flix compiler:

# Syntax Highlighting

Code fragments now have syntax highlighting, making them easy to read—whether
single-line:

![unexpected argument](unexpected-argument.png)

Or multi-line:

![mismatched types](mismatched-types.png)

# Straight To The Point

Simple errors are kept brief and friendly. No need for lengthy explanations when
the issue is clear:

![duplicate annotation](duplicate-annotation.png)

# Detailed Explanations

For more complex errors, we provide detailed explanations with examples:

![missing implementation](missing-implementation.png)

And suggestions to guide you toward a fix:

![constructor not found](constructor-not-found.png)

For the most intricate cases, we go even further with comprehensive explanations:

![complex instance](complex-instance.png)

That's all for now. Hope you enjoy our new colors!