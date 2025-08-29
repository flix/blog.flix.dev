+++
title = "Redundancies as Compile-Time Errors"
date = 2020-02-01
authors = ["Magnus Madsen"]

[taxonomies]
tags = ["bug-finding", "correctness", "flix"]
+++

As software developers, we strive to write correct and maintainable code. Today, I want to share some code where I failed in these two goals.

I will show you real-world code from the Flix compiler and ask you to determine what is wrong with the code. Then, later, I will argue how programming languages can help avoid the type of problems you will see. (Note to the reader: The Flix compiler is (currently) written in Scala, so the code is in Scala, but the lessons learned are applied to the Flix programming language. I hope that makes sense.)

Let us begin our journey by looking at the following code fragment:

```scala
case Expression.ApplyClo(exp, args, tpe, loc) =>
    val e = visitExp(exp)
    val as = args map visitExp
    Expression.ApplyClo(e, as, tpe, loc)

case Expression.ApplyDef(sym, args, tpe, loc) =>
    val as = args map visitExp
    Expression.ApplyDef(sym, as, tpe, loc)

case Expression.Unary(op, exp, tpe, loc) =>
    val e = visitExp(exp)
    Expression.Unary(op, exp, tpe, loc)

case Expression.Binary(op, exp1, exp2, tpe, loc) =>
    val e1 = visitExp(exp1)
    val e2 = visitExp(exp2)
    Expression.Binary(op, e1, e2, tpe, loc)
```

Do you see any issues?

If not, look again.

Ok, got it?

The code has a subtle bug: In the case for `Unary` the local variable `e` holds the result of the recursion on `exp`. But by mistake the reconstruction of `Unary` uses `exp` and not `e` as intended. The local variable `e` is unused. Consequently, the specific transformations applied by `visitExp` under unary expressions are silently discarded. This bug was in the Flix compiler for some time before it was discovered.

Let us continue our journey with the following code fragment:

```scala
case ResolvedAst.Expression.IfThenElse(exp1, exp2, exp3, tvar, evar, loc) =>
    for {
        (tpe1, eff1) <- visitExp(exp1)
        (tpe2, eff2) <- visitExp(exp2)
        (tpe3, eff3) <- visitExp(exp3)
        condType <- unifyTypM(mkBoolType(), tpe1, loc)
        resultTyp <- unifyTypM(tvar, tpe2, tpe3, loc)
        resultEff <- unifyEffM(evar, eff1, eff2, loc)
    } yield (resultTyp, resultEff)
```

Do you see any issues?

If not, look again.

Ok, got it?

The code has a similar bug: The local variable `eff3` is not used, but it should have been used to compute `resultEff`. While this bug never made it into any release of Flix, it did cause a lot of head-scratching.

Now we are getting the hang of things! What about this code fragment?:

```scala
/**
  * Returns the disjunction of the two effects `eff1` and `eff2`.
  */
def mkOr(ef1f: Type, eff2: Type): Type = eff1 match {
    case Type.Cst(TypeConstructor.Pure) => Pure
    case Type.Cst(TypeConstructor.Impure) => eff2
    case _ => eff2 match {
        case Type.Cst(TypeConstructor.Pure) => Pure
        case Type.Cst(TypeConstructor.Impure) => eff1
        case _ => Type.Apply(Type.Apply(Type.Cst(TypeConstructor.Or), eff1), eff2)
    }
}
```

Do you see any issues?

I am sure you did.

The bug is the following: The formal parameter to `mkOr` is misspelled `ef1f` instead of `eff1`. But how does this even compile, you ask? Well, unfortunately the `mkOr` function is nested inside another function that just so happens to have an argument also named `eff1`! Damn Murphy and his laws. The intention was for the formal parameters of `mkOr` to shadow `eff1` (and `eff2`), but because of the misspelling, `ef1f` ended up as unused and `eff1` (a completely unrelated variable) was used instead. The issue was found during development, but not before several hours of wasted work. Not that I am bitter or anything...

We are almost at the end of our journey! But what about this beast:

```scala
/**
 * Returns the result of looking up the given `field` on the given `klass`.
 */
def lookupNativeField(klass: String, field: String, loc: Location): ... = try {
    // retrieve class object.
    val clazz = Class.forName(klass)
    
    // retrieve the matching static fields.
    val fields = clazz.getDeclaredFields.toList.filter {
        case field => field.getName == field && 
                      Modifier.isStatic(field.getModifiers)
    }
    
    // match on the number of fields.
    fields.size match {
        case 0 => Err(NameError.UndefinedNativeField(klass, field, loc))
        case 1 => Ok(fields.head)
        case _ => throw InternalCompilerException("Ambiguous native field?")
    }
} catch {
    case ex: ClassNotFoundException => 
        Err(NameError.UndefinedNativeClass(klass, loc))
}
```

Do you see any issues?

If not, look again.

Ok, got it?

Still nothing?

*Pause for dramatic effect.*

Morpheus: What if I told you...

Morpheus: ... that the function has been maintained over a long period of time...

Morpheus: *But that there is no place where the function is called!*

I am sorry if that was unfair. But was it really? The Flix code base is more than 100,000 lines of code, so it is hard to imagine that a single person can hold it in his or her head.

As these examples demonstrate, and as has been demonstrated in the research literature (see e.g. [Xie and Engler 2002](https://web.stanford.edu/~engler/p401-xie.pdf)), redundant or unused code is often buggy code.

To overcome such issues, Flix is very strict about redundant and unused code.

## Flix Treats Unused Code as Compile-Time Errors

The Flix compiler emits a *compile-time error* for the following redundancies:

| Type                         | Description                                                                    |
|:-----------------------------|:-------------------------------------------------------------------------------|
| Unused Def                   | A function is declared, but never used.                                        |
| Unused Enum                  | An enum type is declared, but never used.                                      |
| Unused Enum Case             | A case (variant) of an enum is declared, but never used.                       |
| Unused Formal Parameter      | A formal parameter is declared, but never used.                                |
| Unused Type Parameter        | A function or enum declares a type parameter, but it is never used.            |
| Unused Local Variable        | A function declares a local variable, but it is never used.                    |
| Shadowed Local Variable      | A local variable hides another local variable.                                 |
| Unconditional Recursion      | A function unconditionally recurses on all control-flow paths.                 |
| Useless Expression Statement | An expression statement discards the result of a pure expression.              |

As the Flix language grows, we will continue to expand the list.

Let us look at three concrete examples of such compile-time errors.

## Example I: Unused Local Variable

Given the program fragment:

```flix
def main(): Bool =
    let l1 = List.range(0, 10);
    let l2 = List.intersperse(42, l1);
    let l3 = List.range(0, 10);
    let l4 = List.map(x -> x :: x :: Nil, l2);
    let l5 = List.flatten(l4);
    List.exists(x -> x == 0, l5)
```

The Flix compiler emits the compile-time error:

```
-- Redundancy Error -------------------------------------------------- foo.flix

>> Unused local variable 'l3'. The variable is not referenced within its scope.

4 |     let l3 = List.range(0, 10);
            ^^
            unused local variable.


Possible fixes:

  (1)  Use the local variable.
  (2)  Remove local variable declaration.
  (3)  Prefix the variable name with an underscore.


Compilation failed with 1 error(s).
```

The error message offers suggestions for how to fix the problem or alternatively how to make the compiler shut up (by explicitly marking the variable as unused).

Modern programming languages like Elm and Rust offer a similar feature.

## Example II: Unused Enum Case

Given the enum declaration:

```flix
enum Color {
    case Red,
    case Green,
    case Blue
}
```

If only `Red` and `Green` are used then we get the Flix compile-time error:

```
-- Redundancy Error -------------------------------------------------- foo.flix

>> Unused case 'Blue' in enum 'Color'.

4 |     case Blue
             ^^^^
             unused tag.

Possible fixes:

  (1)  Use the case.
  (2)  Remove the case.
  (3)  Prefix the case with an underscore.

Compilation failed with 1 error(s).
```

Again, programming languages like Elm and Rust offer a similar feature.

## Example III: Useless Expression Statement

Given the program fragment:

```flix
def main(): Int =
    List.map(x -> x + 1, 1 :: 2 :: Nil);
    123
```

The Flix compiler emits the compile-time error:

```
-- Redundancy Error -------------------------------------------------- foo.flix

>> Useless expression: It has no side-effect(s) and its result is discarded.

2 |     List.map(x -> x + 1, 1 :: 2 :: Nil);
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
        useless expression.


Possible fixes:

  (1)  Use the result computed by the expression.
  (2)  Remove the expression statement.
  (3)  Introduce a let-binding with a wildcard name.

Compilation failed with 1 error(s).
```

The problem with the code is that the evaluation of `List.map(x -> x + 1, 1 :: 2 :: Nil)` has no side-effect(s) and its result is discarded.

Another classic instance of this problem is when someone calls e.g. `checkPermission(...)` and expects it to throw an exception if the user has insufficient permissions, but in fact, the function simply returns a boolean which is then discarded.

But this is *not* your Grandma's average compile-time error. At the time of writing, I know of no other programming language that offers a similar warning or error with the same precision as Flix. If you do, please drop me a line on Gitter. (Before someone rushes to suggest `must_use` and friends, please consider whether they work in the presence of polymorphism as outlined below).

The key challenge is to (automatically) determine whether an expression is pure (side-effect free) in the presence of polymorphism. Specifically, the call to `List.map` is pure because the *function argument* `x -> x + 1` is pure. In other words, the purity of `List.map` depends on the purity of its argument: it is *effect polymorphic*. The combination of type inference, fine-grained effect inference, and effect polymorphism is a strong cocktail that I plan to cover in a future blog post.

Note: The above is fully implemented in master, but has not yet been "released".

## Closing Thoughts

I hope that I have convinced you that unused code is a threat to correct and maintainable code. However, it is a threat that can be neutralized by better programming language design and with minor changes to development practices. Moreover, I believe that a compiler that reports redundant or unused code can help programmers – whether inexperienced or seasoned – avoid stupid mistakes that waste time during development.

A reasonable concern is whether working with a compiler that rejects programs with unused code is too cumbersome or annoying. In my experience, the answer is no. After a small learning period, whenever you want to introduce a new code fragment that will not immediately be used, you simple remember to prefix it with an underscore, and then later you come back and remove the underscore when you are ready to use it.

While there might be a short adjustment period, the upside is *huge*: The compiler provides an iron-clad guarantee that all my code is used. Moreover, whenever I refactor some code, I am immediately informed if some code fragment becomes unused. I think such long-term maintainability concerns are significantly more important than a little bit of extra work during initial development.

Until next time, happy hacking.
