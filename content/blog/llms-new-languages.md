+++
title = "Will LLMs Help or Hurt New Programming Languages?"
description = "A perspective on how LLMs might impact the adoption of new programming languages."
date = 2026-01-02
authors = ["Magnus Madsen"]

[taxonomies]
tags = ["llms", "language-design", "flix"]
+++

Recently, I've seen a number of discussions circle around the same question:

> **Will large language models (LLMs) help or hurt the adoption of new programming languages?**

It is a fair and timely question. As an academic researcher in programming
language design and theory, and as the lead developer of the [Flix programming
language](https://flix.dev), will I soon be out of a job? Well, maybe not!

In this post, I want to explore whether a modern LLM — here, Claude Code (Opus
4.5) — is able to program in Flix. This is an interesting question because the
amount of training data, e.g. Flix source code, is tiny compared to what exists
for languages like Python and JavaScript.

Given that LLMs are reasonably good at translating between natural languages,
e.g. from English to German, I think there is good reason to believe that they
can also support new programming languages, if those languages are syntactically
and semantically similar to existing ones. 

But what happens when a new programming language introduces entirely new syntax
and semantics? For example, the Flix programming language is built around
**effect-oriented programming**. Will Claude be able to use that?

> **Aside:** How much information about Flix is actually in Claude’s training
> set? Surely, Anthropic has scooped up our research papers, vacuumed our
> documentation, and gobbled our source code. Yet Flix evolves rapidly, and some
> information, e.g. from early research papers, may already be slightly
> outdated.

## Experiment: Vibe Coding Tic-Tac-Toe

Today, we will "Vibe Code" (I dislike that term) a Tic-Tac-Toe game in Flix
using Claude Code with the Opus 4.5 model. I chose Tic-Tac-Toe because it is a
well-defined game that requires a moderate use of effects.

My intuition is that writing a new Flix program from scratch is harder for an
LLM because there is no codebase it can gradually evolve, where the exsting
syntax and semantics can serve as examples. There is only the LLM itself and any
information we put into its context. 

We begin by creating an empty Flix project:

```sh
mkdir tictactoe
cd tictactoe
flix init
```

Next, we are going to help Claude by downloading the entire
[Flix API](https://api.flix.dev/) reference and the
[Flix Book](https://doc.flix.dev/) documentation:

```sh
mkdir -p docs
cd docs/
wget -r -np -k https://api.flix.dev/
wget -r -np -k https://doc.flix.dev/
```

The two downloads take a few minutes. If you’re reading this blog post, you have
my permission to crawl our documentation just like we did above.

Next, we create a `CLAUDE.md` file with the following text:

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

## Effect System

Flix has an effect system. Documentation is in `docs/doc.flix.dev/`:

- `effect-system.html` - Core effect system concepts
- `effect-polymorphism.html` - Effect polymorphism
- `effect-oriented-programming.html` - Effect-oriented programming
- `effects-and-handlers.html` - Effects and handlers
```

We explicitly instruct Claude on how to run the compiler and what documentation
to consult about the effect system. 

We can now start. We run `claude` and enter `plan` mode. 

We give it the following prompt:

```prompt
Let us write a tictactoe game in Flix. The game should ask the user for 
a grid size (e.g. 3x3 or 4x4) and then prompt the user for a move. Check 
that the move is valid according to the rules of tictactoe. After each 
player move, the AI makes a valid move. A player wins when they have 
three consecutive x's or o's. 

Use the Console effect for user input and output. Use a functional data
structure to store the game state.

Use a recursive function for the game loop.

Use the Logger effect to log all moves in the game. Write your own custom
handler for Logger that writes to a logfile using the FileWrite effect.

Consult the Flix documentation as necessary during planning.
```

The prompt is reasonable, but not very polished. We let Claude chew on the
instructions and it comes back with: 

```claude
I'll help you create a Tic-Tac-Toe game in Flix. 

Let me first explore the Flix documentation to understand the effect 
system, Console, and FileWrite APIs.
```

After a few minutes, we are asked a few questions, including:

```claude
How sophisticated should the AI opponent be?

❯ 1. Random valid moves
     AI picks any random empty cell - simple to implement
  2. Basic strategy
     AI blocks wins and takes winning moves when available
  3. Minimax algorithm
     Optimal AI that never loses - more complex implementation
```

Initially, I wanted to pick **(3)**. However, choosing **(1)** is actually more
challenging, because it requires Claude to use the `Random` effect, whose
handler introduces the primitive `NonDet` effect. Claude will have to figure
this out on its own. 

We make our choice:

```claude
Now I have clear requirements. Let me design the implementation plan.
```

After about seven minutes of `Clauding...`, which involves reading both the Flix
API reference and documentation, including `Random.html` (which looks
promising), Claude reports back with the full plan (which I have abbreviated):

```flix
 1. Data Type Definitions 
 ...
 type alias GameState = { board = Board, size = Int32, currentPlayer = Player, moveCount = Int32 }
 type alias Move = { player = Player, row = Int32, col = Int32 }
 ...

 2. Custom Logger Effect

 eff Logger {
     def logMove(m: Move): Unit
 }

 3. Core Functions ...

 4. I/O Functions ...

 5. Logger Handler with FileWrite

 def handleLoggerWithFile(logFile: String, f: Unit -> a \ ef): a \ (ef - Logger) + FileWrite =
     run {
         f()
     } with handler Logger {
         def logMove(m, resume) = {
             let line = "${m.player} played at (${m.row + 1}, ${m.col + 1})\n";
             FileWrite.append({str = line}, logFile);
             resume()
         }
     }

 6. Recursive Game Loop

 def gameLoop(state: GameState): GameResult \ {Console, Logger, Random} = ...

 7. Main Entry Point

 def main(): Unit \ IO =
     let logFile = "game_log.txt";
     FileWrite.runWithIO(() ->
         handleLoggerWithFile(logFile, () ->
             Random.runWithIO(() ->
                 Console.runWithIO(() ->
                     startGame()
                 )
             )
         )
     ) |> ignore

 Effect handling order (inner to outer): Console -> Random -> Logger -> FileWrite -> IO

 8. Implementation Steps ...

 9. Win Detection Strategy ...

 10. User Input Format ...
```

Overall the plan looks reasonable, but there are a few issues:

1. Claude wants to define its own `Logger` effect instead of using the `Logger`
  effect from the Standard Library with a custom effect handler.
1. The `main` function, while reasonable, does not use the more idiomatic
  `run-with` construct nor does it use default handlers.
1. Claude wants to use records for `GameState` and `Move`. Typically this trips
  up Claude because Flix uses `rec#field` for field selection, not `rec.field`
  which is used for Java interoperability. 

We give Claude instructions to resolve **(1)** and **(2)**, and warn about **(3)**. But
instead, let us see how well Claude does without further help. Later, we can
return and ask Claude to refactor **(1)** and **(2)**. We proceed:

```claude
The plan is approved. Let me set up a task list and start implementing.
```

Claude generates about 350 lines of code and asks for permission to use the Flix
compiler which I grant. The project contains 20+ errors (including parse errors,
name resolution errors, and type errors). Claude says: 

```claude
I see several issues. The main ones are:
  1. Logger is already defined in the standard library - 
    I need to rename it to GameLogger
  2. The backtick syntax doesn't work with qualified names - 
    need to use Int32.mod(index, size)
```

Claude has discovered that `Logger` is already defined, so it decides to use
`GameLogger`. Claude also assumed that Flix had infix syntax for modulo, but
discovered that instead it should use `Int32.mod`. Note that Claude is using
both the Flix API and Book to make these decisions. 

> **Aside:** The Flix compiler is highly resilient which means that it is
> error-recovering. In particular, about 95% errors are recoverable which allows
> the compiler to proceed to subsequent phases. The upshot is that for a program
> generated by an LLM, Flix is able to report almost all errors in one go which
> allows the LLM to fix the errors quicker without several rounds of
> trial-and-errors. 

Claude fixes the above problems, and reruns the compiler. Now it gets:

```claude
>> Unable to unify the types: 'Player' and 'JvmToType(j0)'.

286 |             match state.currentPlayer {
                        ^^^^^^^^^^^^^^^^^^^
```

The Flix error message here is not great -- we are working on it -- the problem
here is that the syntax `state.currentPlayer` means to access the
`currentPlayer` field on a _Java object_, but `state` is a Flix _record_.
Undauted, Claude continues: 

```claude
I see several issues. 

Let me check the Flix documentation for the correct syntax:

I see! In Flix, record field access uses # not .. So state.size 
should be state#size. 

Let me also search for the correct modulo syntax:

 Now I understand. Let me rewrite the file with the correct syntax:
  - Record access: state#size instead of state.size
  - Modulo: Int32.modulo(index, size)
```

So far these problems have been related to syntax and not to effects. But Claude
has several type and effect errors trying to use them. Including incorrect use of
`do` (which is no longer needed and has been removed from the language. Does
Claude have some old knowledge from papers?)

```claude
 I see! Key insights:
  1. Random.runWithIO introduces NonDet effect (which is uninterpretable)
  2. Random.runWithSeed(seed, f) handles Random without NonDet
  3. No do keyword - effect operations are called directly
```

Claude fixes these. A single type error remains:

Last error:

```claude
Good progress! Just one error left - 
    String.split already returns a List, not a Vector. Let me fix that:
```

And done! The program compiles. Lets try it:

```sh
flix run 

Welcome to Tic-Tac-Toe!
======================
Enter grid size (3-9):
3

Starting 3x3 game. You are X, AI is O.
Get 3 in a row to win!

   1 2 3
1  . . .
2  . . .
3  . . .
Your turn (X):
Enter your move (row col), e.g., '1 2':
1 2 
   1 2 3
1  . X .
2  . . .
3  . . .
AI is thinking...
AI plays at (3, 3)
   1 2 3
1  . X .
2  . . .
3  . . O

... 

   1 2 3
1  X X O
2  X X .
3  O . O
AI is thinking...
AI plays at (3, 2)
   1 2 3
1  X X O
2  X X .
3  O O O
Player O wins!
```

And I lost! 

Recall that we asked Claude to log all moves. Lets see if it did so. 

The `game_log` file is there:

```txt
=== Tic-Tac-Toe Game Log ===
X played at (1, 2)
O played at (3, 3)
X played at (1, 1)
O played at (1, 3)
X played at (2, 2)
O played at (3, 1)
X played at (2, 1)
O played at (3, 2)
```

## Refactoring the Game

Let us return to our own TODO list. We wanted Claude to fix two issues:

1. Claude was using its own `GameLogger` effect, but we wanted it to use the
   built-in `Logger` effect, but with a custom handler.
1. The `main` entry point is correct, but non-idiomatic. 

Let us start with **(1)**. We prompt Claude:

```prompt
Refactor the project to use the built-in Logger effect.
```

Claude consults the Flix API and Book again. 

```claude
I now understand the built-in Logger API. The refactoring involves:

  1. Removing the custom GameLogger effect
  2. Using Logger.info(message) instead of GameLogger.logMove(move)
  3. Writing a custom handler for the built-in Logger that writes to
  file using FileWrite
```

Notably Claude has figured out that it has to write its own handler for `Logger`
which _itself_ uses the `FileWrite` effect. I ask Claude to continue. The
refactoring is successful. The `GameLogger` effect is removed and `Logger` is
used. The new custom handler is:

```flix
// Named "handleLoggerWithFile" but renamed to h to fit on the screen.
def h(logFile: String, f: Unit -> a \ ef): a \ (ef - Logger) + FileWrite =
    run {
        f()
    } with handler Logger {
        def log(severity, msg, resume) = {
            let line = "[${severity}] ${msg}\n";
            FileWrite.append({str = line}, logFile);
            resume()
        }
    }
```

Notably, Claude has figured out the correct syntax for an effect polymorphic
function that handles `Logger` while causing the `FileWrite` effect, i.e. the
signature: 

```flix
def h(logFile: String, f: Unit -> a \ ef): a \ (ef - Logger) + FileWrite = 
```

Impressive!

Next, I want to fix **(2)** by asking Claude to use default handlers. This is a new
feature that is barely used in any examples and only documented in the book. I prompt:

```prompt
Refactor main to use default handlers for the built-in effects.

Use run-with for the Logger effect and custom handler.

See @docs/doc.flix.dev/default-handlers.html for documentation.
```

At this point the dreaded "compacting conversation" happens. Lets see how it goes.

After a bit of `Clauding...`:

```claude
The error shows that `Random` doesn't have a default handler.
Let me check the documentation more carefully:

Read(docs/doc.flix.dev/default-handlers.html)
⎿  Read 284 lines

I see - the documentation shows Clock, Env, and Logger have 
default handlers, but Random may not. Let me check the Random API:

Search(pattern: "@DefaultHandler", path: "docs/api.flix.dev")
⎿  Found 10 lines (ctrl+o to expand)

Console and Logger have default handlers, but Random does not. 
I need to keep Random.runWithIO() explicit:
```

The refactoring completes successfully. The new `main` is:

```flix
def main(): Unit \ {Console, IO, NonDet} =
    let logFile = "game_log.txt";
    // Initialize log file
    discard FileWrite.runWithIO(() -> FileWrite.write({str = "=== Tic-Tac-Toe Game Log ===\n"}, logFile));
    // Run the game - Console uses default handler, Random/Logger/FileWrite need explicit handlers
    discard FileWrite.runWithIO(() ->
        handleLoggerWithFile(logFile, () ->
            Random.runWithIO(() ->
                startGame()
            )
        )
    )
```

Ugh. This is not good. While the code works, its structure is terrible. A few
things have gone wrong, which was partly our own fault:

- We asked Claude to use default handlers for all effects. However, the
  `FileWrite` effect lacks a default handler because it can fail. Specifically,
  `FileWrite.runWithIO` returns a `Result[IoError, Unit]`. Claude, in its
  infinite wisdom, decided that we should just discard the `Result`.
- We asked Claude to use the `run-with` construct, but it simply ignored us. 

Let us try again, but this time we will be more specific:

```prompt
I want you to refactor main. I want it to use a single run-with construct.
Let bind the result to a local variable called r. Inside the run, you
should call FileWrite.write and startGame. You should then use "with" to
install the handlers handleLoggerWithFile and Random.runWithIO. Lastly,
pattern match on the result r, and print an error message using
Console.println if it is Result.Err.
```

Now Claude consults the Flix documentation to learn about `run-with` and produces: 

```
def main(): Unit \ {Console, IO, NonDet} =
    let logFile = "game_log.txt";
    let r = run {
        FileWrite.write({str = "=== Tic-Tac-Toe Game Log ===\n"}, logFile);
        startGame()
    } with handleLoggerWithFile(logFile)
      with Random.runWithIO
      with FileWrite.runWithIO;
    match r {
        case Result.Err(e) => Console.println("Error: ${e}")
        case Result.Ok(_) => ()
    }
```

Much better. The example shows that Claude is able to program effectively (no
pun intended!) with a rich collection of effects. Here we have a program that
uses the `Console`, `FileWrite`, `Logger`, and `Random` effects. Embracing the
richness of the domain, we handle the `Logger` effect using
`handleLoggerWithFile` which causes the `FileWrite` effect. We then handle the
remaining effects using their associated `runWithIO` handlers which introduces the
_primitive_ effects `IO` and `NonDet`. 

> **Aside:** The program here illustrates how in an effect-oriented programming
> languages, effects are pushed outwards towards `main` where they must be handled.
> That is to say, all the dependency injection and plumbing typically happens near `main`,
> while most of the program remains pure modulo effects.

We might be disappointed that `main` is so complex. Why could we not use default
handlers for `FileWrite` and `Random`? The answer is two-fold. With respect to
`Random`, there is a limitation in Flix that prevents it. With respect to
`FileWrite`, the API pushes errors into the handler (instead of at the call
sites), hence we must deal with failure ourselves. (Here by printing to the
terminal). An alternative choice would have been to use `FileWriteWithResult`
which would force clients, i.e. the game, to deal with errors. Then we could
have used a default handler in `main` at the cost of additional complexity
within the game logic. 

## Overview

For reference here some of effectful functions of the game:

```flix
def aiMove(state: GameState): (Int32, Int32) \ Random =
def cellToChar(cell: Cell): String =
def displayBoard(state: GameState): Unit \ Console =
def parseInt(s: String): Option[Int32] =
def promptGridSize(): Int32 \ Console =
def promptMove(state: GameState): (Int32, Int32) \ Console =
def handleLoggerWithFile(logFile: String, f: Unit -> a \ ef): a \ (ef - Logger) + FileWrite =
def gameLoop(state: GameState): GameResult \ {Console, Logger, Random} =
def startGame(): Unit \ {Console, Logger, Random} =
def main(): Unit \ {Console, IO, NonDet} =
```

Note that Claude did a great job at not using `IO` anywhere except for in
`main`. Moreover, each function only has the effects it reasonably needs. 

We can look at a few examples:

```flix
def startGame(): Unit \ {Console, Logger, Random} =
    Console.println("Welcome to Tic-Tac-Toe!");
    Console.println("======================");
    let size = promptGridSize();
    let state = initGameState(size);
    Console.println("");
    Console.println("Starting ${size}x${size} game. You are X, AI is O.");
    Console.println("Get 3 in a row to win!");
    Console.println("");
    discard gameLoop(state)
```

Here `startGame` has the `Console`, `Logger`, and `Random` effects. `Console` is
used directly, whereas `Logger` and `Random` are used by `gameLoop`. 

Here is the function that asks for the size of the grid:

```flix
def promptGridSize(): Int32 \ Console =
    Console.println("Enter grid size (3-9):");
    let input = Console.readln();
    match parseInt(String.trim(input)) {
        case Some(n) if n >= 3 and n <= 9 => n
        case _ =>
            Console.println("Invalid size. Please enter a number between 3 and 9.");
            promptGridSize()
    }
```


## Lessons Learned

I think the key lessons are that:

- Giving Claude access to the Flix API and Book is invaluable. Claude is very
  good at consulting both the API and documentation when it needs to use a
  feature or encounters a problem. 
- Letting Claude run the compiler repeatedly is very helpful. Moreover, the Flix
  compiler being highly resilient allows Claude to discover and fix many errors in one go; meaning that only few compilations are actually required. 

The code style Claude uses is not great, but it is also not terrible. In fact,
considering that Claude was never given a single large program, but only
snippets from the Flix Book, it's impressive how well it did. 


## Conclusions

Returning to main question of the blog post: 

> **Will large language models (LLMs) help or hurt the adoption of new programming languages?**

Based on my personal experience, I think the LLMs will help the adoption of new
programming languages. In this blog post, we have seen that by giving Claude
access to the Flix compiler together with Flix API and language documentation it
becomes a decent Flix programmer. 

We saw that Claude struggle slightly on some specific aspects, but with a
well-crafted `CLAUDE.md` these misunderstandings can easily be cleared up.

In my view, the future of new programming languages looks as bright as ever. 

Until next time, happy Clauding.
