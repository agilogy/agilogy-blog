---
layout: kotlin-post
title:  "What is an automated test, again?"
categories: kotlin,fp
---

{::options syntax_highlighter="nil" /}

Back in the day, we used to just hack some code, run it, and give it some inputs to see whether we acomplished what we wanted or not. Naturally, this is no longer the case, and nowadays we use automated tests to automatically check our code behaves as expected.

I know, I know... 

![Bored Boring GIF - Bored Boring Ntc - Descubre & Comparte GIFs](/assets/bored-boring.gif)

## Basic unit testing

But let's revisit how do we test a simple program. Bear with me, please, as many people and teams just skiped that part of the explanation when talking about tests to their juniors.

Let's imagine we have a simple function like this one:

```kotlin
interface Example{
  //sampleStart
  fun sum(a: Int, b: Int): Int
  //sampleEnd
}
```

A classical **test suite** is a collection of **test scenarios** each of which tests one combination of inputs to the function following these simple steps:

1. Invoke the function with input values defined in the test
2. Collect the result returned by the function and **assert**[^1] it is what we expect

Like this:

{: data-runnableIn='junit'}
```kotlin
import org.junit.*
import org.junit.Assert.*
class Example() {
  fun sum(a: Int, b: Int): Int = a + b
//sampleStart
  @Test fun testSumPositives() {
    assertEquals(23, sum(21,2))
  }

  @Test fun testSumPositiveAndNegative() {
    assertEquals(19, sum(21,-2))
  }
//sampleEnd    
}
```

Easy peasy! Isn't it?

## Not so basic unit testing: Side effects everywhere!

But, what about impure functions? You know I love pure functions, right?

<img src="/assets/agile_jordi.jpg" alt="agile_jordi" style="zoom:70%;" />

What happens whey you want to test something that is not a pure function?

### Testing non total procedures

Let's start with totality, as that one is easy. When a function is not total, you can 2 different things in your tests:

1. Avoid testing inputs for which the function is not defined
2. Test the function fails properly when it is not defined

The first approach is valid when you don't care about such cases. Don't look at me, I always care, because I don't want my types to lie to me. But you may not care and that's a topic for another post. 

The second one is doable by hand with `try ... catch`, although every testing library I know offers some higher level solution:

{: data-runnableIn='junit'}
```kotlin
import org.junit.*
import org.junit.Assert.*


class Example() {
    inline fun <reified T : Throwable> assertThrows(executable: () -> Unit): T =
        when (val throwable: Throwable? = try { executable() } catch (caught: Throwable) { caught } as? Throwable) {
            null -> throw IllegalArgumentException("Expected an exception of type ${T::class} but none was thrown")
            is T -> throwable
            else -> throw throwable
        }

    //sampleStart
    fun div(a: Int, b: Int): Int = a / b

    @Test
    fun divBy0() {
        val t = assertThrows<ArithmeticException> { div(23, 0) }
        assertEquals("/ by zero", t.message)
    }
//sampleEnd

}
```

### Testing non deterministic procedures: State

Like you know, a procedure is not deterministic when, for the same inputs, it may return different outputs. One very good reason for not returning the same input is having state. If you query the amount in your savings bank account you don't expect it to be always the same. You expect the result of such a procedure to depend on the state of what is being test.

Take this simple accumulator:

```kotlin
class MemoryAdder(){
  var lastInput: Int
  fun add(a: Int): Int = (lastInput + a).also{ lastInput = a }
}
```

How do we test the `getCounter` method? As the result depends on the state of the accumulator, we need a new algorithm:
1. Set an initial state defined in the test
2. Invoke the function with input values defined in the test
3. Collect the result returned by the function and **assert** it is what we expect
4. Collect the final state of the system under test and **assert** it is what we expect

Note that many developers and teams forget step number 4. If you don't check the final state of the system under test, such system can behave as you expected in your test and, still, fail to end in the state you expect it to have at the end.

Other teams, though, forget about step number 1. If your system uses any kind of persistent state, that means you are testing it with whatever is in such storage when you launch the test. And that grants you some headache whenever that state is not the one you expected. That can be caused by some other test changing some state you didn't anticipate it would change, you or some other developer running tests in concurrency with your test execution... You know. I've seen things you people wouldn't believe.

But I digress... Let's apply our new algorithm:

{: data-runnableIn='junit'}
```kotlin
import org.junit.*
import org.junit.Assert.*

class MemoryAdderTest() {
    class MemoryAdder(){
      var lastInput: Int = 0
      fun add(a: Int): Int = (lastInput + a).also{ lastInput = a }
    }

		@Test fun testAdderWithSate() {
      //sampleStart
      // 1. Set initial state:
      val ma = MemoryAdder()
      ma.add(23)
      // 2 and 3. Execute the method and assert
      assertEquals(25, ma.add(2))
      // 4. Collect the final state and assert
      assertEquals(2, ma.lastInput)
			//sampleEnd
    }

}
```

Good job! Done, right? Not quite yet...

What if your function is not deterministic because... it generates random values? Or just because it uses the current system time? And what about it doing some I/O, like reading from the file system, a database or a socket? Even more, what about procedures generating some kind of externally observable effect, like **writing** to the file system or a databse? 🙀 [^2]

Let's talk about these dreaded scenarios in our next post about software testing!

I hope you enjoyed this one. See you soon!

---


[^1]: Asserting here means that you check the value is what you expected or else make the test fail
[^2]: Yes, it's a **cat** screaming. Yes, pun intended.