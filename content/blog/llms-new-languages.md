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

Vibe coding is harder because there is no working code base. 

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
- **Examples**: `https://github.com/flix/flix/tree/master/examples`

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

We can now start. We run `claude` and enter `plan` mode. I am using Claude Opus 4.5:

```sh
Let us write a tictactoe game in Flix. The game should ask the user for a grid size
(e.g. 3x3 or 4x4) and then prompt the user for a move. Check that the move is valid
according to the rules of Tic-Tac-Toe. After each player move, the AI makes a valid move.
A player wins when they have three consecutive x's or o's. 

Use the Console effect for user input and output. Use a functional data structure to
store the game state. Use a recursive function for the game loop. 

Add use the Logger effect to log all valid moves in the game. 
Write your own custom handler for Logger that writes to a logfile using the FileWrite effect.

Consult the Flix documentation as necessary during planning.
```

We let Claude chew on that a bit. It comes back with:

```sh
I'll help you create a Tic-Tac-Toe game in Flix. 
Let me first explore the Flix documentation to understand the effect system, Console, and FileWrite APIs.
```

After about 4 minutes, there are some questions to ask:

```
For larger grids (e.g., 4x4 or 5x5), should the win condition always be 3 in a row, or should it match the grid size (e.g., 4 in a row for 4x4)?
```
I say "Always 3 in a row".

```
How sophisticated should the AI opponent be?

❯ 1. Random valid moves
     AI picks any random empty cell - simple to implement
  2. Basic strategy
     AI blocks wins and takes winning moves when available
  3. Minimax algorithm
     Optimal AI that never loses - more complex implementation
```

I pick Random because this will require another effect usage that I have not told Claude about. 

```
Now I have clear requirements. Let me design the implementation plan.
```

After about 7 minues of Clauding... During this its reading some more docs.
Including Random.html (promising!). The plan is long. 

```
---
 1. Data Type Definitions

 enum Player with Eq, ToString { case X, case O }
 enum GameResult with Eq, ToString { case Win(Player), case Draw, case Continue }
 type alias Cell = Option[Player]
 type alias Board = Vector[Cell]  // Flat: index = row * size + col
 type alias GameState = { board = Board, size = Int32, currentPlayer = Player, moveCount = Int32 }
 type alias Move = { player = Player, row = Int32, col = Int32 }

 2. Custom Logger Effect

 eff Logger {
     def logMove(m: Move): Unit
 }

 3. Core Functions

 | Function        | Signature                                         | Purpose                        |
 |-----------------|---------------------------------------------------|--------------------------------|
 | emptyBoard      | Int32 -> Board                                    | Create NxN empty board         |
 | initGameState   | Int32 -> GameState                                | Initialize game                |
 | toIndex         | (Int32, Int32, Int32) -> Int32                    | Convert (row,col) to index     |
 | isValidMove     | (Int32, Int32, GameState) -> Bool                 | Validate move                  |
 | makeMove        | (Int32, Int32, GameState) -> GameState \ Logger   | Apply move, log it             |
 | checkLine       | (row, col, dRow, dCol, Player, GameState) -> Bool | Check 3-in-a-row from position |
 | hasWon          | (Player, GameState) -> Bool                       | Check if player won            |
 | checkGameResult | GameState -> GameResult                           | Win/Draw/Continue              |
 | getEmptyCells   | GameState -> List[(Int32, Int32)]                 | List empty positions           |
 | aiMove          | GameState -> (Int32, Int32) \ Random              | Pick random empty cell         |

 4. I/O Functions

 | Function       | Signature                             | Purpose                  |
 |----------------|---------------------------------------|--------------------------|
 | displayBoard   | GameState -> Unit \ Console           | Print board grid         |
 | promptGridSize | () -> Int32 \ Console                 | Get/validate grid size   |
 | promptMove     | GameState -> (Int32, Int32) \ Console | Get/validate player move |

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

 def gameLoop(state: GameState): GameResult \ {Console, Logger, Random} =
     displayBoard(state);
     match checkGameResult(state) {
         case Win(p) => println("Player ${p} wins!"); Win(p)
         case Draw   => println("It's a draw!"); Draw
         case Continue =>
             match state.currentPlayer {
                 case X => // Human: prompt, validate, make move, recurse
                 case O => // AI: pick random, make move, recurse
             }
     }

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

 8. Implementation Steps

 1. Define data types: Player, GameResult, Cell, Board, GameState, Move
 2. Define Logger effect
 3. Implement board functions: emptyBoard, toIndex, fromIndex, isValidPos, getCell
 4. Implement move functions: isValidMove, makeMove, switchPlayer, getEmptyCells
 5. Implement win detection: checkLine (checks 3 consecutive), hasWon, isBoardFull, checkGameResult
 6. Implement AI: aiMove using Random effect
 7. Implement I/O: displayBoard, promptGridSize, promptMove
 8. Implement Logger handler: handleLoggerWithFile
 9. Implement game loop: gameLoop (recursive), startGame
 10. Implement main: Wire up all effect handlers

 9. Win Detection Strategy

 For 3-in-a-row on any NxN grid:
 - For each cell (r, c), check 4 directions: right, down, diagonal-right, diagonal-left
 - Only check if 3 cells fit within bounds
 - Use recursive helper to verify 3 consecutive same-player cells

 10. User Input Format

 - Grid size: Single integer (e.g., "3" for 3x3)
 - Moves: Two integers for row and column, 1-indexed (e.g., "1 2" for row 1, col 2)
 - Invalid input prompts retry with error message
```

A few problems here:
- Defining custom Logger effect. What I wanted was to use the std lib Logger effect, but with a custom handler.
- main entry point is not using run-with construct.
- Claude wants to use records, but Flix uses the uncommon rec#field syntax. 

I decide that 1 and 2 can be refactored afterwards. I could hint about the records,
but let us see how it goes. So I tell Claude to go ahead!

```
The plan is approved. Let me set up a task list and start implementing.
```

I let Claude use the Flix compiler.

First issue is the redefinition of Logger. This is quickly fixed by renaming to GameLogger.

Now its stuck on the record syntax:

```
>> Unable to unify the types: 'Player' and 'JvmToType(j0)'.

286 |             match state.currentPlayer {
                        ^^^^^^^^^^^^^^^^^^^
```

Next up:  

```
⏺ I see several issues. Let me check the Flix documentation for the correct syntax:

⏺ I see! In Flix, record field access uses # not .. So state.size should be state#size. Let me also search for the correct modulo syntax:

 Now I understand. Let me rewrite the file with the correct syntax:
  - Record access: state#size instead of state.size
  - Modulo: Int32.modulo(index, size)
```

Getting closer. Two problems now:

do GameLogger.logMove(move); -- which is old syntax
type erro related to Random.

Again Claude goes to the docs:

 I see! Key insights:
  1. Random.runWithIO introduces NonDet effect (which is uninterpretable)
  2. Random.runWithSeed(seed, f) handles Random without NonDet
  3. No do keyword - effect operations are called directl

Last error:

⏺ Good progress! Just one error left - String.split already returns a List, not a Vector. Let me fix that:

And done! The file is 336 lines of Flix code. 

Lets try it:

```
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

The game_log file is there:

```
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

Lets return to the TODO list:

- Defining custom Logger effect. What I wanted was to use the std lib Logger effect, but with a custom handler.
- main entry point is not using run-with construct.

Lets start with 1:

```
Refactor the code base to use the built-in Logger effect
```

Claude consults the Flix documentation again. 

```
I now understand the built-in Logger API. The refactoring involves:

  1. Removing the custom GameLogger effect
  2. Using Logger.info(message) instead of GameLogger.logMove(move)
  3. Writing a custom handler for the built-in Logger that writes to file using FileWrite
```







Ingredients for success:

- Docs
- APIs
- Runnable compiler with reasonable error messages. (Resiliency helps here.)