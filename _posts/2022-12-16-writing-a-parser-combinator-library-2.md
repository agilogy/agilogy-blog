---
layout: post
title: >- 
  Writing a Parser Combinator Library in Scala 3.<br>
  Part 2: Choices and repetitions
author: Jordi Pradel
categories: [scala,parsers,design,fp]
description: >-
  We continue to build a Scala 3 parser combinator library by developing a Json parser using TDD. After some initial steps in part 1, we now want to parse arrrays and objects. For that, we'll need to handle choices (when we want to parse either one thing or another one) and sequences (when we want to parse one thing and then another one).
---

In [our previous post](/2022-11-11-writing-a-parser-combinator-library-1.html) we created a small Scala parser capable only of parsing empty Json arrays with possible whitespace. While doing so we designed a parser to be a function that takes an input and an index within that input and returns some result of a given type `A` or fails with a `ParseError`:

```scala
type Parser[A] = (String, Int) => Either[ParseError, A]
```

We then saw that we can create values of type `Parser[A]` and functions that, given some argument, return parsers:

```scala
val whitespace: Parser[Int] = ...
val array: Parser[JsonArray] = ...
def string(token: String): Parser[Int] = ...
```

Finally we created a couple of combinators: `sequence` (aka `**`) takes 2 parsers of type `Parser[Int]` (where the `Int` represents the position after parsing something) and it returns a parser that applies both parsers in sequence and returns the last result, the position after parsing both; and `map`  takes a `Parser[A]` and a function `A => B` and returns a `Parser[B]`.

That allowed us to create a parser like this:

```scala
val array: Parser[JsonArray] =
  (string("[") ** whitespace ** string("]")).map(_ => JsonArray(List.empty))
```

In this post we will explore the parsing of other Json elements that will give us new parser combinators.

## Parsing JsonBoolean

A boolean in Json is simply either `true` or `false`. We already know how to build a `Parser` that parses such strings:

```scala
val jsonTrue: Parser[JsonBoolean] = 
  string("true").map(_ => JsonBoolean(true))
val jsonFalse: Parser[JsonBoolean] = 
  string("false").map(_ => JsonBoolean(false))
```

 But we want a parser of JsonBoolean that is able to parser any of these 2 values:

```scala
  test("Parse boolean") {
    assert(boolean("true", 0) == Right(JsonBoolean(true)))
    assert(boolean("false", 0) == Right(JsonBoolean(false)))
  }
```

🔴

We can implement a parser for Json booleans trying to parse `true` first. If that fails it will simply try to parse `false` at the same position. This is doable with the `orElse` member of `Either` that returns the `this` if its a `Right` or returns its argument, which is another (lasyly evaluated) `Either`:

```scala
val boolean: Parser[JsonBoolean] = (s, position) =>
  jsonTrue(s, i) orElse jsonFalse(s, position)
```

✅ We try to parse a `true` and if we succeed, we call it a day. If we don't succeed, `orElse` will return the result of trying to parse a `false`.

♻️ (refactor) In the solution above, like we did in the previous post, we are programming what the parser does by hand, dealing with the `s` and `position` parameters of parsers. But we would like to abstract those into a combinator of parsers:

```scala
extension [A](self: Parser[A])
  def |(other: Parser[A]): Parser[A] = (s, position) =>
    self(s, position) orElse other(s,position)  

val boolean: Parser[JsonBoolean] = jsonTrue | jsonFalse
```

✅ Great!

But what about failure? We would like to get an error that tells we were expecting either `true` or `false`:

```scala
test("Parse boolean failure") {
  val input = "notABoolean"
  assert(boolean(input, 0) == Left(ParseError(input, 0, List("true", "false"))))
}
```

🔴 Compilation error. Our current `ParseError` class can only hold one expected `String` and we now want a `List` of them. Let's change that class and fix all the compilation issues and we are still in red:

```bash
Left(ParseError("notABoolean", 0, List("false"))) did not equal Left(ParseError("notABoolean", 0, List("true", "false")))
ScalaTestFailureLocation: com.agilogy.wapl.JsonParserTest at (JsonParserTest.scala:45)
```

When it fails to parse, our solution so far only keeps the last alternative it evaluated and complains about expecting only that last option. Let's try to fix that:

```scala
extension [A](self: Parser[A])
  def |(other: Parser[A]): Parser[A] = (s, position) =>
    self(s, position) match
      case Right(a) => Right(a)
      case Left(e1) => other(s, position) match
        case Right(a) => Right(a)
        case Left(e2) => Left(e2.copy(expected = e1.expected ++ e2.expected))
```

✅ 

## Parsing arrays... of 2 boolean values

Ok, I'm feeling lucky! Let's try to parse something more difficult. What about `[true, false]` or the other combinations of an array of two boolean values?

```scala
test("Parse array of true values") {
  assert(booleanArray("[true,false]", 0) == 
    Right(JsonArray(List(JsonBoolean(true), JsonBoolean(false))))
  )
}
```

🔴, of course.

Let's implement `booleanArray` like we only cared about arrays of 2 booleans, for now:

```scala
  val booleanArray: Parser[JsonArray] =
    string("[") ** jsonBoolean ** string(",") ** jsonBoolean ** string("]")
```

The first issue is we don't have a sequencing combinator (`**`) for parsers other than `Parser[Int]`.  Let's try to fix that. We want to generalize ` sequence` (`**`) to any kind of parsers.

```scala
extension [A](self: Parser[A])
	infix def sequence[B](other: Parser[B]): Parser[???] = ...
```

First question arised. What should we return when we parse an `A` and then a `B`? It seems only natural to return the tuple of both values:

```scala
extension [A](self: Parser[A])
  infix def sequence[B](other: Parser[B]): Parser[(A,B)] = (s, position) =>
    for
      a <- self(s, position)
      b <- other(s, ???)
    yield (a,b)
```

But now we have another issue. We implemented `sequence` for parsers that returned the position after parsing. But we now have parsers that already return a meaningful value (a `JsonBoolean`) and we need to know the position after parsing so that we can combine them with other parsers in sequence.

One solution is to redefine our `Parser` type. We `git stash save wip` our changes and:

```scala
type Parser[A] = (String, Int) => Either[ParseError, (A, Int)]
```

🔴 Lots of things are broken, because the new `Parser` type is not comptaible with the old one.

Let's just fix them. Some examples:

```scala
def string(token: String): Parser[Unit] = (s, position) =>
  if (s.startsWith(token, position)) Right(() -> (position + token.length))
  else Left(ParseError(s, position, List(token)))

extension [A](self: Parser[A])
  def map[B](f: A => B): Parser[B] = (s, position) =>
    self(s, position).map((a, finalPosition) => f(a) -> finalPosition)
```

In particular, let's see how `sequence` ends up _implemented_{:.sidenote-number}_It seems the bug that makes destructuring not possible in for comprehensions, which is [an old friend of mine](https://contributors.scala-lang.org/t/pre-sip-improve-for-comprehensions-functionality/3509), is still around in Scala 3. That was not expected. Oh, it seems to be resolved... [in the nightly build of upcoming Scala 3.3](https://dotty.epfl.ch/docs/reference/changed-features/pattern-bindings.html#pattern-bindings-in-for-expressions)._{:.sidenote}:

```scala
extension[A](self: Parser[A])
  infix def sequence[B](other: Parser[B]): Parser[(A, B)] = (s, position) =>
    for
      aI0 <- self(s, position)
      (a, i0) = aI0
      bI1 <- other(s, i0)
      (b, i1) = bI1
    yield (a -> b) -> i1
```

And our tests for successful parsings need to be rewritten to add the position after parsing:

```scala
test("Parse empty array") {
  assert(array("[]", 0) == Right(JsonArray(List.empty),2))
}
```

✅ Green! ♻️ But those tests are starting to be unconvenient. All of our tests try to parse at position 0, like the end users of our parsers will do. And they tend to not care about what the final position of the parsing is. Let's add another `apply` for that:

```scala
extension[A](self: Parser[A])
  def apply(s: String): Either[ParseError, A] = self(s, 0).map(_._1)
```

 So our tests are now simpler:

```scala
test("Parse empty array") {
  assert(array("[]") == Right(JsonArray(List.empty)))
}
```

✅ But with one concern. We expect the end user parser to fail if we encounter unexpected content after parsing a json value:

```scala
test("Parse empty array failure, unexpected content") {
  val input = "[]wut?"
  assert(array(input) == Left(ParseError(input, 2, List("end of input"))))
}
```

🔴 `Right(JsonArray(List())) did not equal Left(ParseError("[]wut?", 2, List("end of input")))`

Let's fix it:

```scala
def apply(s: String): Either[ParseError, A] =
  self(s, 0) match
    case Right((_, endPosition)) if endPosition < s.length =>
      Left(ParseError(s, endPosition, List("end of input")))
    case r => r.map(_._1)
```

✅  Good!

♻️ But now, when a parser error says it was expecting `end of input` does it mean the end of the input or the string `"end of input"`? Let's put all other string between quotes to distinguish that:

```scala
test("Parse empty array failure, missing ]") {
  val input = "["
  assert(array(input) == Left(ParseError(input, 1, List("\"]\""))))
}

test("Parse empty array failure, unexpected content") {
  val input = "[]wut?"
  assert(array(input) == Left(ParseError(input, 2, List("end of input"))))
}
```

Now we can `git stash pop` our parser of arrays of two booleans and finish it:

```scala
val booleanArray: Parser[JsonArray] =
  (string("[") ** boolean ** string(",") ** boolean ** string("]"))
    .map { case ((((_, b1), _), b2), _) => JsonArray(List(b1, b2)) }
```

✅! ♻️ But that destructured argument to `map` was ugly. Let's try to fix it with some more sugar. My idea is that whenever we sequence a parser of `Unit` and any other parser of any type `A`, we don't care about the `Unit` value and we just want the `A`, not a `Pair<Unit,A>`. I'll create an extension for `Parser[Unit]` where `sequence` ignores the `Unit` and I'll add a `sequence` version taking a `Parser[Unit]` that ignores that other `Unit`. As I'll need the original `sequence` in multiple places, I define it at the root level:

```scala
def _sequence[A, B](a: Parser[A], b: Parser[B]): Parser[(A, B)] = ... 

extension (self: Parser[Unit])

  infix def sequence[B](other: Parser[B]): Parser[B] = _sequence(self, other).map(_._2)
  def **[B](other: Parser[B]): Parser[B] = _sequence(self, other).map(_._2)

end extension

extension [A](self: Parser[A])

  infix def sequence[B](other: Parser[B]): Parser[(A, B)] = _sequence(self, other)
  @targetName("sequenceUnit")
  infix def sequence(other: Parser[Unit]): Parser[A] = _sequence(self, other).map(_._1)

  def **[B](other: Parser[B]): Parser[(A, B)] = sequence(other)
  @targetName("starStarUnit")
  def **(other: Parser[Unit]): Parser[A] = sequence(other)

end extension

```

Now our array parser is:

```scala
val booleanArray: Parser[JsonArray] =
  (string("[") ** boolean ** string(",") ** boolean ** string("]"))
    .map { case (b1, b2) => JsonArray(List(b1, b2)) }
```

## Parsing arrays of booleans

Let's say we want to parse arrays (of booleans) of any length, now:

```scala
test("Parse array of boolean values") {
  val length = random.between(3, 5)
  val booleans = (0 until length).map(_ => random.nextBoolean()).toList
  assert(booleanArray(s"[${booleans.map(_.toString).mkString(",")}]") ==
    Right(JsonArray(booleans.map(JsonBoolean)))
  )
}
```

🔴 After the second boolean it expects `]` but we give it more booleans.

This time, we will start by solving the problem with some combinators and _invent_ new ones whenever we need them:

```scala
string("[") **
   ((boolean ** (string(",") ** boolean).repeated) | empty) ** 
string("]")
```

The idea is to have `[`, then the array contents and then `]`. The array contents may be empty or they may be a boolean followed by 0 or more times the combination of a comma and a boolean. But now we want our types to fit in this idea. Let's see that in detail:

We already know that `(string(",") ** boolean)` is of type `JsonBoolean`

`p.repeated` is intended to represent a parser that parses whatever `p` parses any number of times, including 0. If `p` is of type `A`, then it will parse any number of chunks as instances of type `A`, giving us a list of values of type `A`:

```scala
extension [A](self: Parser[A])
  def repeated: Parser[List[A]] = ???
```

Therefore, `(string(",") ** boolean).repeated` gives us a `List[JsonBoolean]`. And `(boolean ** (string(",") ** boolean).repeated`, is of type  `(JsonBoolean,List[JsonBoolean])`. If we want all in a `JsonArray`, we must map that parser. The `empty` parser returns whatever value we want; and we want an empty `JsonArray`.

```scala
val booleanArray: Parser[Json] =
  string("[") ** (
      (boolean ** (string(",") ** boolean).repeated).map { case (b, l) => JsonArray(b :: l)} | 
      empty(JsonArray(List.empty))
    ) ** string("]")
```

![repetition](../assets/recursiveRepetition.gif)
{:.sidenote}
_Repetition... by self-recursion! How cool is that?_{:.figcaption}

Now we need to implement `repeated`. Here is one fancy way with just the combinators we already have and a recursive definition:

We can define a parser `repeated` that, when needed, tries to parse some content with `repeated` itself. Like a function calling itself but with parsers. 

Let's see how that turns out:

```scala
def repeated: Parser[List[A]] = (self ** repeated).map(_ :: _) | empty(List.empty)
```

It compiles! Let's run our tests:

```bash
An exception or error caused a run to abort. 
java.lang.StackOverflowError
	at com.agilogy.wapl.Parser$package$ParserOps.repeated(Parser.scala:54)
	at com.agilogy.wapl.Parser$package$ParserOps.repeated(Parser.scala:54)
```

🔴 Ops! When defining `repeated` it calls `repeated`. `StackOverflowError`.

But we may use some lazyness here. After all, `sequence` (or `**`) won't need the second parser unless the first one succeeds. It seems only natural for it (and its variants) to evaluate that second parser lazyly:

```scala
def _sequence[A, B](a: Parser[A], b: => Parser[B]): Parser[(A, B)] = ...

extension (self: Parser[Unit])

  infix def sequence[B](other: => Parser[B]): Parser[B] = _sequence(self, other).map(_._2)
  def **[B](other: => Parser[B]): Parser[B] = _sequence(self, other).map(_._2)

end extension

extension [A](self: Parser[A])

  infix def sequence[B](other: => Parser[B]): Parser[(A, B)] = _sequence(self, other)
  @targetName("sequenceUnit")
  infix def sequence(other: => Parser[Unit]): Parser[A] = _sequence(self, other).map(_._1)
  def **[B](other: => Parser[B]): Parser[(A, B)] = _sequence(other)
  @targetName("starStarUnit")
  def **(other: Parser[Unit]): Parser[A] = _sequence(other)

end extension
```

✅ ! But... What about long arrays. Let's change our test to generate arrays of length `random.between(10000, 10005)`:

```bash
An exception or error caused a run to abort. 
java.lang.StackOverflowError
	at scala.runtime.BoxesRunTime.boxToInteger(BoxesRunTime.java:63)
	at com.agilogy.wapl.Parser$package$ParserOps.map$$anonfun$1(Parser.scala:37)
```

🔴 Ouch! This time the cause is not an infinite recursion, but simply one too deep. So let's be a bit less fancy and implement `repeated` by hand. That is, we run a tailrec loop where we try to parse the content with the parser we want repeatedly applied. If it doesn't parse, we stop repeating and return the accumulated list of parsed values so far (which may be empty). If it does parse, we repeat at the new position.

```scala
def repeated: Parser[List[A]] = (s, position) =>
  @tailrec
  def loop(acc: List[A], pos: Int): (List[A],Int) =
    self(s, pos) match
      case Left(_) => (acc.reverse, pos)
      case Right(a, newPos) => loop(a::acc, newPos)
  Right(loop(List.empty, position))
```

✅ ! 

♻️ Let's refactor a bit... We now have 2 array parsers: an `array` parser that only accepts whitespace and a `booleanArray` parser that only accepts booleans. Let's remove the former and make the later accept whitespace by using `whitespace`{:.sidenote-number}_I should, in fact, allow whitespace in many other places, like between the `","` and the next boolean. But let me add that to the backlog and keep going._{:.sidenote} instead of `empty`:

```scala
val array: Parser[Json] =
  string("[") **
    ((boolean ** (string(",") ** boolean).repeated).map {
      case (b, l) => JsonArray(b :: l)
    } | whitespace.map(_ => JsonArray(List.empty)))
    ** string("]")
```

✅ 

## Other primitives

Let me continue with the parsing of other primitive values. Let's start with Json numbers. The grammar for Json numbers occupies some space of your screen but it is not complex:

<img src="../assets/json-number.png" alt="img" style="zoom:33%;" /> 

We chose to represent `JsonNumber` by its internal string representation instead of trying to represent it with a numeric Scala or Java value. That allows us to just focus on `Json` and let our users treat that number however _they want_{:.sidenote-number}_Json numbers are decimal numbers without any bound. `Int`, `Long` and any other integer primitive type won't be able to hold values if they are out of the allowed range of values. And `Float` and `Double` types, being floating point representations, won't be able to correctly represent some decimal values. Still, in many occasions, a `Long` or a `Double` may suffice if you know your `Json` use case is not amongst those that cause issues. We could use something like a BigDecimal, but I prefer to simply give our user the `String` and let them decide how to use them._{:.sidenote}. Now we won't try to normalize parsed numbers, just parse them and return their string representation.

```scala
test("Parse json numbers") {
  assert(number("1") == Right(JsonNumber("1")))
  assert(number("0.1") == Right(JsonNumber("0.1")))
  assert(number("-0.1") == Right(JsonNumber("-0.1")))
  assert(number("-0.1") == Right(JsonNumber("-0.1")))
  assert(number("-0.1e2") == Right(JsonNumber("-0.1e2")))
  assert(number("-0.1e+2") == Right(JsonNumber("-0.1e+2")))
  assert(number("-0.1e-2") == Right(JsonNumber("-0.1e-2")))
}
```

🔴 because it doesn't compile and 🔴 once we write `number` to return `???`.

We could parse numbers by hand with our current combinators, probably. But them being tokens, it seems easier to just use a Regex:

```scala
val number: Parser[JsonNumber] =
  regex("number", "-?([1-9][0-9]*|0)(\\.[0-9]+)?([eE][\\-+]?[0-9]+)?".r).map(JsonNumber.apply)
```

Where:

```scala
def regex(label: String, regex: Regex): Parser[String] = (s, position) =>
  regex.findPrefixOf(s.substring(position))
    .map(m => Right(m, position + m.length))
    .getOrElse(Left(ParseError(s, position, List(label))))
```

✅ All tests green.

What about `Json` strings? The full grammar is:

```
string
    '"' characters '"'
characters
    ""
    character characters
character
    '0020' .. '10FFFF' - '"' - '\'
    '\' escape
```

Let me implement just a simplified version where we don't have escape characters. We can implement them fully later. To test valid characters I'll test the two edge values. The char `10FFFF` can be encoded in UTF-16 as `0xDBFF 0xDFFF`. So:

```scala
test("Parse json strings") {
  assert(string("\"\"") == Right(JsonString("")))
  assert(string("\"Json\"") == Right(JsonString("Json")))
  assert(string("\"No només ASCII\"") == Right(JsonString("No només ASCII")))
  assert(string("\"\u0020\udbff\udfff\"") == Right(JsonString("\u0020\udbff\udfff")))
}
```

🔴 In fact, I find I used the name `string` for generic parsers and now I want to use it for `JsonParser`. I don't like the mess I get where I need to import the correct one, so I rename the generic parsers `string` to `token` and add a `string` parser to `JsonParser`. Now it compiles, let's implement it so it passes the tests.

As I'm just implementing a simplified version without escape chars, I'll just use another regex to accept any char that is not a `"`:

```scala
val string: Parser[JsonString] = regex("string", "\"[^\"]*\"".r)
  .map(s =>  JsonString(s.substring(1, s.length - 1)))
```

✅ Done!

## Parsing Json arrays, at last... (without objects)

Now I can close the circle and try to implement arrays of arbitrary Json values... except objects which I don't have implemented yet.

```scala
  test("Parse array of values and arrays") {
    assert(array("[1,false,\"hello\",[true,3]]") ==
      Right(JsonArray(List(
        JsonNumber("1"),
        JsonBoolean(false),
        JsonString("hello"),
        JsonArray(List(JsonBoolean(true), JsonNumber("3")))
      ))))
  }
```

🔴 This time it compiles, but the test fails with:

```bash
Expected :Right(...)
Actual   :Left(ParseError("[1,false,"hello",[true,3]]", 1, List(""]"")))
```

I don't like that error message very much. That's my fault, as I have paid no attention to error messages for many commits now. But I'm in the midle of a Red-Green-Refactor cycle, so this is not the moment. Let's add that to a backlog. And now let's focus on the task at hand. My approach is to finally parse any `Json` value we support so far:

```scala
val json: Parser[Json] = boolean | string | number | array
```

And now `array` can contain `json` values instead of just `boolean` values:

```scala
val array: Parser[Json] =
  token("[") ** (
      (json ** (token(",") ** json).repeated).map { case (b, l) => JsonArray(b :: l) } | 
      whitespace(JsonArray(List.empty))
  ) ** token("]")
```

My IntelliJ warns me that referring `json`, which I have defined after `array`, is a suspicious forward reference. Furthermore, the reference is circular, because `array` uses `json` and `json` uses `array`.  But let's just run the tests and see what happens...

✅ Wow! How that even worked? Remember we defined `**`'s second parameter to be lazyly evaluated and, therefore,  `json` wont't get immediately evaluated when defining `array`. It is no longer using a forward reference before that reference takes a value. And there is no more a problematic circular reference: when defining `array` it won't use `json` right away, then `json` will get defined and, finally, by when we use the `array` parser, `json` will have been already evaluated.

♻️ Refactor? There may be many options. I'll peek some:

- Make `|`'s second parameter lazyly evaluated like we do in `**`. After all, the second argument to `|` will only be needed if the first argument fails to parse.

- Sort the tests so all Json primitive tests go first and all array tests come later.

- Mark parsers not representing json types private: `whitespace`, `jsonTrue`, `jsonFalse`

- Add a helper function for the usual case where we map to some value ignoring the current value ( e.g. `p.map(_ => JsonBoolean(true))`): `p.as(JsonBoolean(true))`.

## Parsing objects

And now, objects! Let's go directly to the TDD cycle:

```scala
test("Parse object") {
  val input = "{\"a\":23,\"b\":[{\"c\":null}]}"
  val expected = JsonObject(Map(
    "a" -> JsonNumber("23"),
    "b" -> JsonArray(List(JsonObject(Map("c" -> JsonNull))))
  ))
  assert(json(input) == Right(expected))
}
```

🔴 Red, of course.

Let's just copy the `array` solution but parse object members (a key, `":"` and a value) instead of just values:

```scala
val member: Parser[(String, Json)] = string.map(_.value) ** token(":") ** json

val obj: Parser[Json] =
  token("{") ** (
    (member ** (token(",") ** member).repeated).map { case (b, l) => JsonObject((b :: l).toMap) } | 
    whitespace.as(JsonObject(Map.empty))
  ) ** token("}")

val json: Parser[Json] = boolean | string | number | array | obj
```

🔴 What!?

```bash
Expected :Right(JsonObject(Map("a" -> JsonNumber("23"), "b" -> JsonArray(List(JsonObject(Map("c" -> JsonNull)))))))
Actual   :Left(ParseError("{"a":23,"b":[{"c":null}]}", 7, List(""true"", ""false"", "string", "number", ""["", ""}"")))
```

Why on earth is it complaining about position 7? What is to be found there is clearly a member `"b":[{"c":null}]`...

After actually spending a lot of minutes trying to figure out here it is: `json` does not yet support nulls. That is of course my fault for using `null` in my test when I don't yet support it. But, why such an ugly error message?? Let me add that to the backlog too and fix the issue now that we know what it was.

```scala
val jsonNull: Parser[JsonNull.type]  = "null".as(JsonNull)
val json: Parser[Json] = boolean | string | number | jsonNull | array | obj
```

✅ Wa yeah!

## Our parsing library so far

The current version of our parser library so far has these functions:

```scala
type Parser[A] = (String, Int) => Either[ParseError, (A, Int)]

def token(token: String): Parser[Unit] = (s, position) => ...
def empty[A](value: A): Parser[A] = (_, position) => ...
def sequence[A, B](a: Parser[A], b: => Parser[B]): Parser[(A, B)] = 
  (s, position) => ...
def regex(label: String, regex: Regex): Parser[String] = (s, position) => ...

extension (self: Parser[Unit])

  infix def sequence[B](other: => Parser[B]): Parser[B] = ...
  def **[B](other: => Parser[B]): Parser[B] = ...

end extension

extension [A](self: Parser[A])

  def apply(s: String): Either[ParseError, A] = ...
  def map[B](f: A => B): Parser[B] = (s, position) => ...
  def as[B](b: B): Parser[B] = ...
  def |(other: => Parser[A]): Parser[A] = (s, position) => ...
  infix def sequence[B](other: => Parser[B]): Parser[(A, B)] = ...
  infix def sequence(other: => Parser[Unit]): Parser[A] = ...
  def **[B](other: => Parser[B]): Parser[(A, B)] = ...
  def **(other: Parser[Unit]): Parser[A] = ...
  def repeated: Parser[List[A]] = (s, position) => ...

end extension
```

If we examine the functions returning `Parser` carefully we'll see that most of them are defined by the implementation of the actual parser, where we receive the string and the position and return the parse result. We'll call those, primitives. But some others, like `as`, are derived from the primitives; we don't implement them by saying how they handle the string and the position to return a parse result but we derive them from some other(s) parser(s) and applying functions on them.

We can, in fact, further refactor our current solution to discover more useful derived functions.

One of them may be useful to represent the repetition of values with some separator:

```scala
def separatedBy(separator: Parser[Unit]): Parser[List[A]] =
  (self ** (separator ** self).repeated).map { case (h, t) => h :: t } | empty(List.empty) 
```

And now we can simplify a couple of definitions in `JsonParser`:

```scala
val array: Parser[Json] =
  token("[") ** whitespace ** 
    json.separatedBy(token(",")).map(JsonArray.apply) 
    ** token("]")
val obj: Parser[Json] =
  token("{") **
    member.separatedBy(token(",")).map(members => JsonObject(members.toMap))
    ** token("}")
```

This being Scala (3) we could add some more sugar. Those `token("foo")` could be replaced with their string value directly:

```scala
given Conversion[String, Parser[Unit]] with
  def apply(str: String): Parser[Unit] = token(str)
```

So now we can write parsers like these:

```scala
val array: Parser[Json] =
  "[" ** whitespace ** json.separatedBy(",").map(JsonArray.apply) ** token("]")
val obj: Parser[Json] =
  "{" ** member.separatedBy(",").map(members => JsonObject(members.toMap)) ** "}"
```

## Our Json parser so far

We have now a quite capable Json parser. Some known limitations we may want to overcome:

- It can't parse Json with whitespace properly
- It can't parse strings with escape sequences
- It has very limited error handling capabilities

## Conclusions

After the very limited but promising features developed in the first part of the series, we developed an almost complete Json parser using a TDD aproach. At the same time, at each "refactor" phase, we abstracted a bunch of useful parser combinator functions, therefore developing a parser combinator library, as we intended.

Beyond the (known) limitations of our Json parser, we now have a quite capable parser combinator library... although we only tested one example grammar we developed with it. And this is one of the drawbacks of this approach compared to the approach in the [Red book](https://www.manning.com/books/functional-programming-in-scala). We now have a parser combinator library but we don't have any tests of the library itself, but just tests of one example parser we implemented with it.

You can see the complete source code of this post here: https://github.com/agile-jordi/writingAParserLibrary/tree/part2.

## All articles in the series

1. [Writing a Parser Combinator Library in Scala 3. Part 1: Introduction to Parsing](./2022-11-11-writing-a-parser-combinator-library-1.html)
2. [Writing a parser library in Scala. Part 2: Choices and repetitions](./2022-12-16-writing-a-parser-combinator-library-2.html)

