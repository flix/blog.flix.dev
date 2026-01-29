+++
title = "Improved Error Messages"
description = "A look at the new and improved error messages in the Flix compiler, featuring syntax highlighting, helpful examples, and detailed explanations."
date = 2026-02-01
authors = ["Magnus Madsen"]

[taxonomies]
tags = ["language-design", "flix"]
+++

Inspired by Elm's
[Compiler Errors for Humans](https://elm-lang.org/news/compiler-errors-for-humans) and
[Compilers as Assistants](https://elm-lang.org/news/compilers-as-assistants),
we recently revisited all error messages in the Flix compiler.

Here is what you can look forward to in the next version of Flix:

Code fragments now have syntax highlighting.

Works for both single-line errors:
![unexpected argument](unexpected-argument.png)

And multi-line errors:
![mismatched types](mismatched-types.png)

Simple errors are kept brief:
![duplicate annotation](duplicate-annotation.png)

For more complex errors, we provide detailed explanations with examples:
![missing implementation](missing-implementation.png)

And, when possible, offer suggestions to guide you towards a fix:
![constructor not found](constructor-not-found.png)

For the most complex errors, we give in-depth technical context:
![complex instance](complex-instance.png)

That's all for now. Hope you enjoy our new colors!