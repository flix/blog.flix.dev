+++
title = "Will LLMs Help or Hurt New Programming Languages?"
description = "A programming language researcher's perspective on how LLMs might impact the adoption of new programming languages."
date = 2025-12-18
authors = ["Magnus Madsen"]

[taxonomies]
tags = ["language-design", "llms", "flix"]
+++

I am a PL researcher working on compilers, type and effect systems, and program
analysis. I am also the lead developer of the Flix programming language
(flix.dev). I am not an AI researcher.

Recently, at work, on HackerNews, and on Reddit I have seen questions to the effect of:

> **Will LLMs aid or hinder adoption of new programming languages?**

In this blog post, I will discuss this question from the viewpoint of a PL
researcher. 

TODO: We will be using claude code.

TODO: Commands to download doc.flix.dev and api.flix.dev + examples

TODO: Not a fan of vibe coding, but lets try it.

TODO: Configure the compiler. 

TODO: We will use all of flixes features to challenge it.

TicTacToe example

We begin as follows:

```sh
mkdir tictactoe
cd tictactoe
flix init
```

We now download the Flix documentation and API. We could of course also access
this material online, but downloading it makes subsequent uses faster:

```sh
mkdir -p docs
cd docs/
wget -r -np -k https://api.flix.dev/
wget -r -np -k https://doc.flix.dev/
```

Running these commands takes less than a minute. (If you are following this blog
post, ou have my personal permission to crawl our sites like this.)

Next, we create a `CLAUDE.md` file with the following:

```markdown
# Overview

This is project is written in the Flix programming language.

## Documentation

- **API Reference**: `docs/api.flix.dev/`
- **Documentation**: `docs/doc.flix.dev/`

## Flix Compiler Commands

The `flix` compiler is available on PATH and supports the following commands:

- `flix check` - Check code for errors
- `flix run` - Run the project
- `flix test` - Run tests

## Effect System

Flix has an effect system. Documentation is in `docs/doc.flix.dev/`:

- `effect-system.html` - Core effect system concepts
- `effect-polymorphism.html` - Effect polymorphism
- `effect-oriented-programming.html` - Effect-oriented programming
- `effects-and-handlers.html` - Effects and handlers
```

We can now start. We run `claude` and enter `plan` mode:

