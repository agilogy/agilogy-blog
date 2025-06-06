---
layout: page
title: Procedure
---

A software **procedure** or subroutine is a callable unit. It may define some **[parameters](https://en.wikipedia.org/wiki/Parameter_(computer_programming))** that act as variables that will contain the values passed to it as **arguments** when invoked, and it may return some result. In statically typed languages, parameters are predefined (giving their name and type) and the return type is also defined.

In statically typed languages a procedure has a signature consisting of:

- The name of the procedure
- The name and type of each parameter
- The type of the result

This may be further extended with some more information:

- Exceptions the procedure may throw (e.g. [Java's throw clause](https://docs.oracle.com/javase/tutorial/essential/exceptions/declaring.html))
- Default parameter values (e.g. [Scala's](https://docs.scala-lang.org/tour/default-parameter-values.html) or [Kotlin's](https://kotlinlang.org/docs/functions.html#default-arguments) default parameter values)
- Coloring labels (e.g. [Kotlin's suspend functions](https://kotlinlang.org/docs/flow.html#suspending-functions))

### Procedures as values

In languages with lambda functions (e.g. Java, Scala, Kotlin, etc) a procedure 𝑓(p0: 𝕏0, ..., pn: 𝕏n): 𝕐 can be expressed as a lambda function 𝑓: (𝕏0, ..., 𝕏n) ⇒ 𝕐. That is, a procedure can be seen as a value whose type is the type of functions taking the procedure parameters and returning the procedure return type.

