---
layout: post
title: What is an automated test, again?
author: Jordi Pradel
categories: [kotlin,testing]
description: >-
  The basic automated testing recipe seems well-known and simple, but it is not sufficient when the system under test is not a pure function. Testing non-total functions is quite well understood. Testing systems with state is a bit more complicated and important details are often overlooked. At Agilogy, our approach to test such systems with state is to explicitly set the initial state of the system before exercising whatever functionality we want to test, and to also get and make assertions about the final state in addition to the usual assertions about any response or returned value. We show this approach applied to one simple toy function and we do so in Kotlin.
---

Back in the day, we used to just hack some code, run it, and give it some inputs to see whether we acomplished what we wanted or not. Naturally, this is no longer the case, and nowadays we use automated tests to automatically check our code behaves as expected.

<!--more-->

![Bored Boring GIF - Bored Boring Ntc - Descubre & Comparte GIFs](../assets/bored-boring.gif)

I know, I know... But let's revisit how do we test a simple program. Bear with me, please, as many people and teams just skiped that part of the explanation when talking about tests to their juniors.

## Basic unit testing

Let's imagine we have a simple function like this one:

```kotlin
fun sum(a: Int, b: Int): Int
```

A classical **test suite** is a collection of **test scenarios** each of which tests one combination of inputs to the function following these simple steps:

1. Invoke the function with input values defined in the test
2. Collect the result returned by the function and _assert_{: .sidenote-number} _**Asserting** here means that you check the value is what you expected or else make the test fail_{: .sidenote} it is what we expect.

Like this:

{: data-runnableIn='junit'}
```kotlin
@Test
fun testSumPositives() {
  assertEquals(23, sum(21, 2))
}

@Test
fun testSumPositiveAndNegative() {
  assertEquals(19, sum(21, -2))
}
```

You probably already know, but just in case: `assertEquals` takes the **expected** value as the **first** argument and the **actual** value, the one your code actually returned, as the **second** argument. Please, please, stop doing the order of those arguments wrong, as failing tests are really confusing when they are switched.

Easy peasy! Isn't it?

## Not so basic unit testing: Side effects everywhere!

But, what about impure "functions"? You know I love pure functions, right?

**Functional programmer** with an agile background
{: .figcaption}

![agile_jordi profile as a functional programmer](../assets/agile_jordi.jpg)

What happens when you want to test something that is not a pure function?

### Testing non total "functions"

Let's start with totality, as that one is easy. A function is total when it returns a result (of the specified type) for every possible input. When a function is not total, you can do 2 different things in your tests:

1. Avoid testing inputs for which the function is not defined
2. Test the function fails properly when it is not defined

The first approach is valid when you don't care about such cases. Don't look at me, I always care, because I don't want my types to lie to me. But you may not care and that's a topic for another post. 

The second one is doable by hand with `try ... catch`, although every testing library I know offers some higher level solution:

{: data-runnableIn='junit'}
```kotlin
fun div(a: Int, b: Int): Int = a / b

@Test
fun divBy0() {
  val t = assertThrows<ArithmeticException> { div(23, 0) }
  assertEquals("/ by zero", t.message)
}
```

There is still a catch. Your function may be non total without you, the poor programming, knowing about it. But if you are lucky enough that one of your tests discovers such a hole in your function, the test library will usually deal with it, showing the thrown exception as a particular case of a test failure:

{: data-runnableIn='junit'}
```kotlin
@Test
fun failingTestDueToUnexpectedException() {
  assertTrue(div(23, 0) < 23)
}
```


### Testing non deterministic "function": State

Like you know, a "function" is not deterministic when, for the same inputs, it may return different outputs. One very good reason for it to not return the same input is having state. If you query the amount in your savings bank account you don't expect it to be always the same. You expect the result to depend on the state of what is being test.

Take this simple adder:

```kotlin
class MemoryAdder(){
  var lastInput: Int
  fun add(a: Int): Int = (lastInput + a).also{ lastInput = a }
}
```

How do we test the `add` method? As the result depends on the state of the `MemoryAdder`, we need a new algorithm:
1. Set an initial state defined in the test
2. Invoke the function with input values defined in the test
3. Collect the result returned by the function and **assert** it is what we expect
4. Collect the final state of the system under test and **assert** it is what we expect

Note that many developers and teams forget step number 4. If you don't check the final state of the system under test, such system can behave as you expected in your test and, still, fail to end in the state you expect it to have at the end.

Other teams, though, forget about step number 1. If your system uses any kind of persistent state, that means you are testing it with whatever is present in such storage when you launch the test. And that grants you some headache whenever that state is not the one you expected. That can be caused by some other test changing some state you didn't anticipate it would change, you or some other developer running tests in concurrency with your test execution, someone doing manual tests using the same database you expected no one to use... You know. I've seen things you people wouldn't believe.

But I digress... Let's apply our new algorithm:

{: data-runnableIn='junit'}
```kotlin
// 1. Set initial state:
val ma = MemoryAdder()
ma.add(23)
// 2 and 3. Execute the method and assert
assertEquals(25, ma.add(2))
// 4. Collect the final state and assert
assertEquals(2, ma.lastInput)
```

Good job! Done, right? Not quite yet...

What if your function is not deterministic because... it generates random values? Or just because it uses the current system time? And what about it doing some I/O, like reading from the file system, a database or a socket? Even more, what about procedures generating some kind of externally observable effect, like **writing** to the file system or a databse? _🙀_{: .sidenote-number} _Yes, it's a **cat** screaming. Yes, coming from Scala, that pun is indeed intended. I didn't find any arrow screaming, sorry about that._{: .sidenote}

Let's talk about these dreaded scenarios in our next post about software testing!

I hope you enjoyed this one. See you soon!

## All the articles in the series

1. [What is an automated test, again?](./2022-05-27-what-is-an-automated-test-again.html)
2. [Testing and persistent state](./2022-06-17-testing-and-persistent-state.html)
3. [Testing other side effects](./2022-07-08-testing-other-side-effects.html)