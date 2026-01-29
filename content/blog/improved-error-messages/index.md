+++
title = "Improved Error Messages"
description = "A tour of the new and improved error messages in the Flix compiler, featuring syntax highlighting, clearer explanations, and actionable suggestions."
date = 2026-02-01
authors = ["Magnus Madsen"]

[taxonomies]
tags = ["language-design", "flix"]
+++

Inspired by Elm's
[Compiler Errors for Humans](https://elm-lang.org/news/compiler-errors-for-humans) and
[Compilers as Assistants](https://elm-lang.org/news/compilers-as-assistants),
we recently took a step back and reworked *every* error message in the Flix compiler.

Here is what you can look forward to in the next version of Flix:

All error messages now have syntax highlighting. For single-line errors:
![unexpected argument](unexpected-argument.png)

And for multi-line errors:
![mismatched types](mismatched-types.png)

Simple errors are kept brief:
![duplicate annotation](duplicate-annotation.png)

Whereas complex errors come with explanations and examples:
![missing implementation](missing-implementation.png)

And, when possible, with suggestions for a fix:
![constructor not found](constructor-not-found.png)

For very complex errors, we now give an in-depth technical explanation:
![complex instance](complex-instance.png)

---

That's all for now.

Hope you enjoy our new colors!