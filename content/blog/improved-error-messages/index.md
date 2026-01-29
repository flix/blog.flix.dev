+++
title = "Improved Error Messages"
description = "TODO"
date = 2026-02-01
authors = ["Magnus Madsen"]

[taxonomies]
tags = ["language-design", "flix"]
+++

Inspired by 

https://elm-lang.org/news/compiler-errors-for-humans

https://elm-lang.org/news/compilers-as-assistants

We recently took the time go through all the Flix compiler messages.

We now have:

- Syntax highlighting!
- All errors have unique error codes.
- Short errors are just that short
- Include important details where relevant
- Difficult errors have explainations

We illustrate with examples:



## With explanation and suggestions

![constructor not found](constructor-not-found.png)

