---
layout: post
title:  "Testing other side effects"
author: "Jordi Pradel"
categories: [kotlin,testing,databases]
description: >-
  Trying to test a simple function with side effects takes us to talk about simplicity and, from there, we take the path of design to try to design a simpler solution. That brings us dependency injection. All because we wanted testability.
---

Previously on Agilogy blog...

> What if your function is not deterministic because... it generates random values? Or just because it uses the current system time? And what about it doing some I/O, like reading from the file system, a database or a socket? Even more, what about procedures generating some kind of externally observable effect, like **writing** to the file system or a databse?
>
> [What is an automated test, again?](./2022-05-27-what-is-an-automated-test-again.html)

<!--more-->

## In which trying to test a function that uses the System clock leads us to design for testing and, finally, to wonder what to test 

Let's take a very simple function:

```kotlin
fun age(birthDate: LocalDate): Int = 
  Period.between(birthDate, LocalDate.now()).years
```

Simple, right? One line, and that means simple, right? Of course not. But why? Let's try to write an automated test for it.

Now, there are at least these 3 typical moments in the life of a developer where you can be in. You may be reading this **puzzled**, not knowing how the hell to test that without having to change the test yearly. Or you start thinking **mocks**. Or you start thinking how to redesign this _one-liner_{:.sidenote-number}_I mean, beyond the ugly implicit usage of the system default time zone, which **I**, at least, would refactor out of my sight._{:.sidenote}.

I'm going to try to take you from puzzled to a better design without going through _mocks_{:.sidenote-number} _Are you already thinking about them? Please, consider this article an alternative to mocking._{:.sidenote}.

The issue with testing this function is, you may have guessed, `Instant.now()`, which would return a different value on each test execution. 

You could, of course, try something like this:

```kotlin
@Test
fun testAge() {
  assertEquals(7, age(LocalDate.of(2014, 7, 30)))
}
```

But then, of course, after my son's birthday party the test will fail and you would need to update it. Nasty.

The problem, here is that we are getting the current date `LocalDate.now()` and that has the odd habit of chaning as time goes by. We are also calculating how many years are there between 2 local dates, which would be fine to test, but... Yes, these 2 _things_ this function does are what Rich Hickey would call _[complected](https://www.youtube.com/watch?v=SxdOUGdseq4)_{:.sidenote-number} _If you haven't seen this famous talk, make yourself a favour and bookmark it: [Simple Made Easy](https://www.youtube.com/watch?v=SxdOUGdseq4). Then, when you are ready, take a cup of your best coffee, tea, mate or whatever is your poison and enjoy an hour of pure talent._{:.sidenote}:

> Okay. So there's this really cool word called **complect**. I found it. I love it. It means to interleave or entwine or braid. Okay?
> ...
> Having state in your program is never simple because it has a  fundamental complecting that goes on in its artifacts. It complects  value and time. (...) Well, if every time you call that method with the same arguments, you  can get a different result, guess what happened? That complexity just  leaked right out of there (...). If the thing that's wrapping it is stateful (...) by stateful I mean every time you ask it the same question you get a different answer, you have this complexity and it's like poison.
> 
> Rich Hickey, _Simple Made Easy_{:.cite}

So, even though it is a one-liner, we want to simplify this function. A first step would be to rule off the function that we find difficult to test:

```kotlin
fun ageOn(today: LocalDate, birthDate: LocalDate): Int =   
  Period.between(birthDate, today).years
```

That one is easy to test. We say it is _testable_{:.sidenote-number} _Testability is, indeed, a software quality factor. But, curiously enough, aiming at testability enhances the quality of your software in other aspects as well._{:.sidenote}. But now the user of the function needs to do what was part of the responsibilities of `age` before: getting the current local date. We can recover our original `age` function defining a new function like this:

```kotlin
fun age(birthDate: LocalDate): Int = ageOn(LocalDate.now(), birthDate)
```

Now we can test we correctly calculated the number of years between two dates and that that is what we actually mean by age:

```kotlin
@Test
fun testAgeOn() {
  assertEquals(
    7,
    ageOn(LocalDate.of(2022, 6, 1), LocalDate.of(2014, 6, 30))
  )
}
```

What about the original `age` function? How do we test that one? We still can't. The problem with testing `age` was, to begin with, that we don't know how to test the part that gets the current local date... So, here are some questions that will make you think:

- How do we test that `LocalDate.now()` returns the current date?
- Assuming we can trust `LocalDate.now()`,  how do we test that `age` uses `LocalDate.now()` and not some other wrong / untrusted / untested method to get the current date?
- Assuming `age` correctly gets the current date somehow, how do we know it is (correctly) using `ageOn`?

Or, put it in another way, even with our test of `ageOn`, each risk in the following list corresponds to one of the questions we were asking above:

- `LocalDate.now()` could be producing the wrong date, not the current date
- `age` could be getting the current date using some untested method that gets it wrong
- `age` could be correctly getting the current date but fail to calculate the number of years between the 2 dates, as we tested `ageOn` but we didn't test wether `age` is invoking it and, if so, if it is handling it the correct arguments in the correct order.

Let's start with the last two concerns here...

## Designing for testability

Let's imagine we solve the first question/concern above _somehow_{:.sidenote-number} _More on that at the end of the article. But let's consider it solved now._{:.sidenote}. What would we need to solve the other two? We want some new version of `age` that we can test, so that we solve the last question. And we want to make sure it uses what we want to get the current local date, so that the second question is also solved.

That is, we want a function that, given the way of getting the current date of our choice and a birth date, gets it and properly calculates the number of years since the birth date to that current date. Do you see what I did there? I just used the same expression for "the way of getting the current date" and "a birth date". Yes, they **both**  can be parameters:

```kotlin
fun age(getCurrentDate: () -> LocalDate, birthDate: LocalDate): Int =
  Period.between(birthDate, getCurrentDate()).years
```

We can now test almost everything we were concerned about:

```kotlin
@Test
fun testAge() {
  val getDate: () -> LocalDate = { LocalDate.of(2022, 6, 1) }
  assertEquals(
    7,
    age(getDate, LocalDate.of(2014, 6, 30))
  )
}
```

Note that `getDate` here is a function that always returns the same result. `() -> LocalDate` is the type of functions that have no parameters and return a `LocalDate`.

Now we can build tests where we check that `age` uses whatever function we pass it as the first argument (our second concern), and that `age` properly calculates the number of years between `birthDate` and the date returned by `getCurrentDate`.

We say that `age` depends on the function that returns the current date and that we _injected_ that dependency into `age`.  

This is just one particular style of dependency injection, one with which you may not be familiar. Some other styles come to mind:
- Instead of injecting `() -> LocalDate` we could have injected an instance of some named type like `interface Clock` that contained methods for what we wanted to acomplish:

```kotlin
fun age(clock: Clock, birthDate: LocalDate): Int =
  Period.between(birthDate, clock.getCurrentDate()).years
```

- Instead of injecting the function or instance as a parameter of the function `age`, we could have put the `age` function in a class and inject something to the class:

```kotlin
class AgeModule(val clock: Clock){
  fun age(birthDate: LocalDate): Int =
    Period.between(birthDate, clock.getCurrentDate()).years
}
```

- Hell, if you are really into monadic stuff, we could have even used a _reader `Monad`_{:.sidenote-number} _I may talk about that in a future article._{:.sidenote}  defining `age` as a function that returns a function that given whatever it needs injected, returns the result we want:

```kotlin
fun age(birthDate: LocalDate): (Clock) -> LocalDate = { clock ->
  Period.between(birthDate, clock.getCurrentDate()).years 
}
```

## What about testing that LocalDate.now() returns the current date?

That one, the one I left unsolved so far is the easiest one to solve. I don't have any clue about how to properly test that, but I don't even care. "How do I test that, then?" - you say. My answer: Don't. Don't test it. _Nada_. _Niente_. _Res de res_.

This may seem silly but it is, in fact, a very important part of our testing strategy at Agilogy. You should not be testing other's code. And by "other's" I mean code in another module. Once you think about it, in fact, it is quite common sense:

- Testing some other module software breaks modularity itself. That other module is responsible for its own stuff, not your module. If something's wrong there, test it there, where you can fix it.
- Testing some other module software is very inefficient. Either it is a module you can trust and it will have tests for that, probably much better tests than those you will come up with, or it is a module you can't trust and then you shouldn't be using it _at all_{:.sidenote-number} _Of course, I'm being a bit too blunt here. You may want to test some open source library does what you expect it too, for example. But I'm assuming we want to test our `age` function here and my point is that testing that a dependency of `age` properly does its work is out of the scope of the tests for `age`._{:.sidenote}.
- If a module B is used by a module A and you own both, testing your module B in A doesn't provide any safety net against changes in B. You may be working on B and breaking things without that test telling you so and you may release a version of B used by some C that was not testing it properly. Boom, you have a bug in production you could have prevented by testing B in B.

## Conclusions

So I cheated you. I told you I was going to talk about testing and I ended up talking about complection, software design and dependency injection.... or didn't I? 

![The Oracle in the Matrix movies, explained before Resurrections - Polygon](../assets/img/Matrix-Oracle.jpeg){: width="200px"}
{:.figcaption}

The Oracle, not the Oracle DB
{:.figcaption}

So we have built a simpler, better `age` function. But, paraphrasing the Oracle, what's really going to bake your noodle later on is, [would we still have reached such simple, elegant solution if I hadn't said anything about testing?](https://youtu.be/eVF4kebiks4?t=31)

## Other articles in the series

1. [What is an automated test, again?](./2022-05-27-what-is-an-automated-test-again.html)
2. [Testing and persistent state](./2022-06-17-testing-and-persistent-state.html)
