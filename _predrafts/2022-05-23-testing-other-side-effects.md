---
layout: kotlin-post
title:  "Testing other side effects"
author: "Jordi Pradel"
categories: kotlin,testing,databases
---

Previously on Agilogy blog...

> What if your function is not deterministic because... it generates random values? Or just because it uses the current system time? And what about it doing some I/O, like reading from the file system, a database or a socket? Even more, what about procedures generating some kind of externally observable effect, like **writing** to the file system or a databse?
>
> [What is an automated test, again?](2022-05-20-what-is-an-automated-test-again.md)

## In which trying to test a function that uses the System clock leads us to design for testing and, finally, to wonder what to test 

Let's take a very simple function:

```kotlin
fun age(birthDate: LocalDate): Int = Period.between(birthDate, LocalDate.now()).years
```

Simple, right? One line, and that means simple, right? Of course not. But why? Let's try to write an automated test for it.

Now, there are at least these 3 typical moments in the life of a developer where you can be in:

1. You are reading this puzzled, not knowing how the hell to test that without having to change the test yearly
2. You start thinking mocks
3. You start thinking how to redesign this one-liner [^1]

I'm going to try to take you from 1 to 3 without going through 2. Are you already at 2? Please, consider this article an alternative to mocking.

The issue with testing this function is, you may have guessed, ` Instant.now()`, which would return a different value on each test execution. 

You could, of course, try something like this:

{: data-runnableIn='junit'}

```kotlin
import org.junit.Assert.assertEquals
import org.junit.Test
import java.time.LocalDate
import java.time.Period

class Example {

    fun age(birthDate: LocalDate): Int = Period.between(birthDate, LocalDate.now()).years
    
    //sampleStart
    @Test
    fun testAge() {
        assertEquals(7, age(LocalDate.of(2014, 6, 30)))
    }
    //sampleEnd
}
```

But then, of course, after my son's birthday party the test will fail and you would need to update it. Nasty.

The problem, here is that we are getting the current date `LocalDate.now()` and that has the odd habit of chaning as time goes by. We are also calculating how many years are there between 2 local dates, which would be fine to test, but... Yes, these 2 _things_ this function does are what Rich Hickey would call [complected](https://www.youtube.com/watch?v=SxdOUGdseq4):

> Okay. So there's this really cool word called complect. I found it. I love it. It means to interleave or entwine or braid. Okay?
>
> ...
>
> Having state in your program is never simple because it has a  fundamental complecting that goes on in its artifacts. It complects  value and time. (...) Well, if every time you call that method with the same arguments, you  can get a different result, guess what happened? That complexity just  leaked right out of there. It doesn't matter that you can't see the variable. If the thing that's wrapping it is stateful and the thing  that's wrapping that is still stateful, in other words by stateful I  mean every time you ask it the same question you get a different answer, you have this complexity and it's like poison.
>

If you haven't seen this famous talk, make yourself a favour and bookmark it. Then, when you are ready, take a cup of your best coffee, tea, mate or whatever is your poison and enjoy an hour of pure talent. But now, let's return to the world of us simple mortals.

So, even being a one-liner, we want to simplify this function. A first step would be to rule off the function that we find difficult to test:

```kotlin
fun ageOn(today: LocalDate, birthDate: LocalDate): Int = Period.between(birthDate, today).years
```

That one is easy to test. We say it is testable. But now the user of the function needs to do what was part of the responsibilities of `age` before: getting the current local date. We can recover our original `age` function defining a new function like this:

```kotlin
fun age(birthDate: LocalDate): Int = ageOn(LocalDate.now(), birthDate)
```

Now we can test we correctly calculated the number of years between two dates and that that is what we actually mean by age:

{: data-runnableIn='junit'}

```kotlin
import org.junit.Assert.assertEquals
import org.junit.Test
import java.time.LocalDate
import java.time.Period

class Example {

    fun ageOn(today: LocalDate, birthDate: LocalDate): Int = Period.between(birthDate, today).years
    
    //sampleStart
    @Test
    fun testAgeOn() {
        assertEquals(7, ageOn(LocalDate.of(2022, 6, 1), LocalDate.of(2014, 6, 30)))
    }
    //sampleEnd
}
```

What about the original `age` function? How do we test that one? We still can't. The problem with testing `age` was, to begin with, that we don't know how to test the part that gets the current local date... So, here are some questions that will make you think:

1. How do we test that `LocalDate.now()` returns the current date?
2. Assuming we can trust `LocalDate.now()`,  how do we test that `age` uses `LocalDate.now()` and not some other wrong / untrusted / untested method to get the current date?
3. Assuming `age` correctly gets the current date somehow, how do we know it is (correctly) using `ageOn`?

Or, put it in another way, even with our test of `ageOn`, each risk in the following list corresponds to the question we were asking above:

1. `LocalDate.now()` could be producing the wrong date, not the current date
2.  `age` could be getting the current date using some untested method that gets it wrong
3. ` age` could be correctly getting the current date but fail to calculate the number of years between the 2 dates, as we tested `ageOn` but we didn't test wether `age` is invoking it and, if so, if it is handling it the correct arguments in the correct order.

Let's start with concerns 2 and 3 here... Enter dependency injection!

## Designing for testability

Let's imagine we solve question number 1 above somehow. More on that at the end of the article. But let's consider it solved now. What would we need to solve questions 2 and 3? We want some new version of `age` that we can test, so that we solve question 3. And we want to make sure it uses what we want to get the current local date, so that question number 2 is also solved.

That is, we want a function that, given the way of getting the current date of our choice and a birth date, gets it and properly calculates the number of years since the birth date to that current date. Do you see what I did there? I just used the same expression for "the way of getting the current date" and "a birth date". Yes, they **both**  can be parameters:

```kotlin
fun age(getCurrentDate: () -> LocalDate, birthDate: LocalDate): Int =
  Period.between(birthDate, getCurrentDate()).years
```

We can now test almost everything we were concerned about:

```kotlin
import org.junit.Assert.assertEquals
import org.junit.Test
import java.time.LocalDate
import java.time.Period

class Example {

    fun age(getCurrentDate: () -> LocalDate, birthDate: LocalDate): Int =
        Period.between(birthDate, getCurrentDate()).years

    //sampleStart
    @Test
    fun testAge() {
        assertEquals(7, age({ LocalDate.of(2022, 6, 1) }, LocalDate.of(2014, 6, 30)))
    }
    //sampleEnd
}
```
Notes:
-  `{LocalDate.of(2022, 6, 1)}` here is a function that always returns the same result
-  `() -> LocalDate` is the type of functions that have no parameters and return a `LocalDate`

Now we can build tests where we check:
- That `age` uses whatever function to pass it as the first argument (concern 2)
- That `age` properly calculates the number of years between `birthDate` and the date returned by `getCurrentDate`, 

We say that `age` depends on the function that returns the current date and that we _injected_ that dependency into `age`.  

Note: This is just one particular style of dependency injection, one with which you may not be familiar. Some other styles come to mind:
- Instead of injecting `() -> LocalDate` we could have injected an instance of some named type like `interface Clock` that contained methods for what we wanted to acomplish:

```kotlin
fun age(clock: Clock, birthDate: LocalDate): Int = Period.between(birthDate, clock.getCurrentDate()).years
```

- Instead of injecting the function or an instance, we could have put the `age` function in a class and inject something to the class:

```kotlin
class AgeModule(val clock: Clock){
  fun age(birthDate: LocalDate): Int = Period.between(birthDate, clock.getCurrentDate()).years
}
```

- Hell, if you are really into monadic stuff, we could have even used a reader `Monad` defining `age` as a function that returns a function that given whatever it need injected, returns the result we want:

```kotlin
fun age(birthDate: LocalDate): (Clock) -> LocalDate = { clock -> Period.between(birthDate, clock.getCurrentDate()).years }
```

## What about testing that LocalDate.now() returns the current date?

That one, the one I left unsolved so far is the easiest one to solve. I don't have any clue about how to properly test that, but I don't even care. "How do I test that, then?" - you say. My answer: Don't. Don't test it. Nada. Niente.

This may seem silly but it is, in fact, a very important part of our testing strategy at Agilogy. You should not be testing other's code. And by "other's" I mean code in another module. Once you think about it, in fact, it is quite common sense:

- Testing some other module software breaks modularity itself. That other module is responsible for its own stuff, not your module. If something's wrong there, test it there, where you can fix it.
- Testing some other module software is very inefficient. Either it is a module you can trust and it will have tests for that, probably much better tests than those you will come up with, or it is a module you can't trust and then you shouldn't be using it at all.
- If a module B is used by a module A and you own both, if your team has ownership on B, the used module, testing it in A doesn't provide any safety net against changes in B. You may be working on B and breaking things without that test telling you so and you may release a version of B used by some C that was not testing it properly. Boom, you have a bug in production you could have prevented by testing B in B.

## Conclusions

So I cheated you. I told you I was going to talk about testing and I ended up talking about complection, software design and dependency injection.... or didn't I? 

So we have built a simpler, better `age` function. But, paraphrasing the Oracle, what's really going to bake your noodle later on is, [would we still have designed it like that if I hadn't said anything about testing?](https://youtu.be/eVF4kebiks4?t=31)


---

[^1]: I mean, beyond the ugly implicit usage of the system default time zone, which **I**, at least, would refactor out of my sight.
