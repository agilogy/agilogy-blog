---

layout: post
title: "Writing a Property Based Testing library in Kotlin, a Journey. Part 4: Housekeeping"
author: Jordi Pradel
categories: [kotlin,propertybasedtesting,pbt,testing,design,fp]
description: >-
  TODO()
---

In the previous articles in this series ([1](./2022-10-04-writing-a-pbt-ibrary-1.html), [2](./2022-10-14-writing-a-pbt-ibrary-2.html) and [3](./2022-10-21-writing-a-pbt-ibrary-3.html)) I've been developing a property based testing library from scratch and blogging about the process. It turns out that such library actually exists as a companion repository you can follow while reading. It's [here](https://github.com/agile-jordi/wapbtl). So far all articles in the series have been about property based testing themselves. But, at the same time, I'm blogging about the actual design of a library.

Today I want to tidy things up a bit and you bet I'll be blogging about this too.

## Reorganizing tests

As I'm using the library to write this blog series, I'm actually programming (and running the tests) for the code I use in the blog. But some of those code fragments are actually usage examples (like `Int` tests, `DayOfWeek` and `Geometry`). I put all of those in a simple package `com.agilogy.wapbtl.examples` so that they are not mixed with actual tests of the library, that will be in `com.agilogy.wapbtl.test`. Examples should probably be in a different project in the multiproject build but I'm frankly not in the mood for a fight with Gradle to get that done. Not now.

As a result of such cleaner separation, our examples of property based testing of `Int` where somehow poor. I thought I needed some other property checked, so I checked `Int` sum is associative:

```kotlin
@Test
fun testAssociativity(){
  forAny(Arb.int, Arb.int, Arb.int){ a, b, c -> (a + b) + c == a + (b + c)}
}
```

I also refactored the class names so all tests (those testing the library and those working as usage examples) all follow the same pattern: `XXXTest`.

## Encountering (and fixing) a bug

When programming the additional `Int` test above I got a green test the first time I run it. I don't know you, but if I don't see a test fail I can't trust it. So I hacked the property so that it failed and I got this:

```kotlin
@Test
fun testAssociativity(){
  forAny(Arb.int, Arb.int, Arb.int){ a, b, c -> (a + b) + c == a + (b + c + 1)}
}
```

```shell
Property failed at attempt 1 with sample false.
Seed: 4769791297438385931
```

It failed ok. I have a seed. Yeah!! But, hey, what the heck means "with sample `false`"??? I wanted it to give me... what, the 3 samples the test used? This is obviously a bug. A design bug, I'd say, as I'm not even sure what `PropertyFailedException` should be like.

📝 A quick retrospective: I said I like to write tests of everything I develop I didn't live up to these expectations. This property based testing library is indeed poorly tested. Let's take note of this technical debt... and, as you do with debts, let's pay it promptly.

But as much as I care about paying this debt, I have a production bug to fix first. Let's fix that. And let's start by designing the solution.

Our current `PropertyFailedException` implementation _is_{:.sidenote-number}_This `Any?` type is something I already hate. And, oh! surprise! it is failing to us now. What I would like is for `PropertyFailedException` to be parameterized like `class PropertyFailedException<A>(val attempt: Int, val seed: Long, val sample: A) `but Kotlin complains with "Subclass of 'Throwable' may not have type parameters". So let's attempt to continue to live with that. For now._{:.sidenote}:

```kotlin
class PropertyFailedException(
  val attempt: Int,
  val seed: Long,
  val sample: Any?
): Exception(...)
```

When `forAny` takes more than one `Arg`, what would the sample be? We could use tuples and have a sample of type `Pair<A, B>` if we were given 2 args, and a `Triple<A, B, C>` if we were given 3. What if we want a `forAny` of 4 or more values? Coming from Scala I'd say bigger tuples (`Tuple4`, `Tuple5`...) would totally make sense here... even though they are not idiomatic in Kotlin. I could use a `List<Any?>` and put all samples in that list, but I hate to have something that poorly typed. So, lacking a better solution, I will go with the two tuples we already have. Any ideas are welcome here, if you want to tweet (with a mention) or DM them. I'm [@agile_jordi](https://twitter.com/agile_jordi).

So now that we decided we expect a tuple, we can fix the test. But, hey, I just did a quick retrospective, right? Don't let the gap grow bigger and fix the test the way tests need to be fixed: by first reproducing them:

```kotlin
@Test
fun forAny2ArbsFailure() {
  val property: (Int, Int) -> Boolean = { a, b -> (a + b) > a }
  var attempts = 0
  val failure = assertFailsWith<PropertyFailedException> {
    forAny(Arb.int, Arb.int) { a, b ->
                              attempts += 1
                              property(a, b) 
                             }
  }
  @Suppress("UNCHECKED_CAST")
  val failedSample = failure.sample as Pair<Int, Int>
  assertFalse { property(failedSample.first, failedSample.second) }
  assertEquals(attempts, failure.attempt)
}
```

So, letting aside the ugly casts, we are testing that whenever a `forAny` that takes two `Arb<Int>` fails, it should return a `Pair<Int,Int>` as the failed sample, and that checking the property on those 2 values should fail. And, it fails. _Yay!_{:.sidenote-number} _Yes, yay! Because when you are writing a test you expect it to be useful. And a test that you write but never fails is giving you exactly 0 value._{:.sidenote} We are also testing what we already tested for the one arbitrary version of `forAny`, to make sure we didn't break the `attempt`result.

```shell
class java.lang.Boolean cannot be cast to class kotlin.Pair
java.lang.ClassCastException: (...)
	at com.agilogy.wapbtl.test.ForAnyTest.(...)
	...
```

Ok, now fix this. The problem is the fancy trick I did to avoid creating a tuple:

```kotlin
fun <A, B, C> forAny(
  a: Arb<A>, b: Arb<B>, c: Arb<C>, seed: Long? = null, 
  property: (A, B, C) -> Boolean
): Unit =
    forAny(Arb.product3(a, b, c, property), seed) { it }
```

Remember? We were building an `Arb<Boolean>` that directly told us whether the property passed or not and passing that to the `forAny` that only takes one `Arb`. Therefore, we can't recover the sample values once the `forAny` fails. But the tuple we wanted to avoid creating is now created at least when the test fails. So I'll undo the trick and simplify things. In the end, this was a premature optimization, probably. Or the Scala developer in me being confused by the lack of tuples in Kotlin. So, let's simplify:

```kotlin
fun <A, B> forAny(
  a: Arb<A>, b: Arb<B>, seed: Long? = null, 
  property: (A, B) -> Boolean
): Unit = 
    forAny(Arb.pair(a, b), seed) { (a, b) -> property(a, b) }

fun <A, B, C> forAny(
  a: Arb<A>, b: Arb<B>, c: Arb<C>, seed: Long? = null,
  property: (A, B, C) -> Boolean
): Unit =
    forAny(Arb.triple(a, b, c), seed) { (a, b, c) -> property(a, b, c) }
```

And now our test passes!

## Test exceptions

That's a basic one I didn't introduce in the first version just for the sake of a simpler explanation of what property based testing means. Imagine you are trying to check a property of Integer division:

```kotlin
@Test
fun testIntegerDivision() {
  forAny(Arb.int, Arb.int) { a, b ->
    val d = a / b
    val m = a % b
    a == b * d + m
  }
}
```

As you already know this is an actual property of integer division... except when b is 0. Of course we can fix the test with a simple `if`, but let's imagine you are not aware what the problem is. The result you currently get is:

```shell
/ by zero
java.lang.ArithmeticException: / by zero
	at com.agilogy.wapbtl.examples....
	...
```

No `PropertyFailedException`, no seed, no samples. You are on your own to understand the problem. And it may be a flaky test, where you were fortunate enough to catch an example that fails... but that doesn't come along that frequently in your test.

As is customary in testing libraries, we would like to treat the throw of an exception as a test failure. Therefore, we may have 3 possible outcomes of the evaluation of your property for a given example(s). Either the property successfully returns `true`, or it successfully returns `false` or it fails with an exception. We'll consider both returning `false` or throwind an exception a way of telling us the property does not abide.

For that we need to... first write a test! 

```kotlin
@Test
fun testForAnyException() {
  val property: (Int) -> Boolean = { i ->
    if (i < 0) throw IllegalArgumentException("$i")
    true
  }
  var attempts = 0
  val failure = assertFailsWith<PropertyFailedException> {
    forAny(Arb.int) {
      attempts += 1
      property(it)
    }
  }
  val failedSample = failure.sample as Int
  assertTrue(failure.cause is IllegalArgumentException)
  assertEquals("$failedSample", failure.cause?.message)
  assertEquals(attempts, failure.attempt)
}
```

Now we can fix our `forAny` implementation and make the test pass:

```kotlin
fun <A> forAny(r: Arb<A>, seed: Long? = null, property: (A) -> Boolean) {
    fun test(currentSeed: Long, attemptNumber: Int) {
        val sample = r.generate(Random(currentSeed))
        runCatching { property(sample) }.fold(
            onSuccess = { result ->
                if (!result) throw PropertyFailedException(attemptNumber, currentSeed, sample)
            },
            onFailure = { exception ->
                throw PropertyFailedException(attemptNumber, currentSeed, sample, exception)
            }
        )
    }
    if (seed == null) {
        (1..100).forEach { attemptNumber ->
            test(Random.Default.nextLong(), attemptNumber)
        }
    } else {
        test(seed, 1)
    }
}
```

`PropertyFailedException` is now:

```kotlin
class PropertyFailedException(
    val attempt: Int,
    val seed: Long,
    val sample: Any?,
    override val cause: Throwable? = null
) : Exception(
    """Property failed at attempt $attempt
        |Sample $sample
        |Seed: $seed
        |Cause: ${cause?.message}""".trimMargin()
)
```

And our int division test now throws:

```shel
com.agilogy.wapbtl.PropertyFailedException: Property failed at attempt 1
Sample (-1838537511, 0)
Seed: -2405689340444717625
Cause: / by zero
	at app//com.agilogy.wapbtl.ForAnyKt.forAny$test(forAny.kt:25)
	...
Caused by: java.lang.ArithmeticException: / by zero
	at com.agilogy.wapbtl.examples.ForAnyIntTest$testIntegerDivision$1...
```

### Your favourite assertion library

As a side effect of handling exceptions as test failures, now you could use your favourite assertions library to check properties if you prefer:

```kotlin
forAny(Arb.int, Arb.int) { a, b ->
  val d = a / b
  val m = a % b
  assertEquals(a, b * d + m)
}
```

That has one important advantage: In case of failure now you get the descriptive behaviour your assertion library carefully provides. And one disadvantatge: it does not compile, because `forAny` expects a function that returns a Boolean. Of course you could return `true`, but that would be horrible. So let's do something about it.

Red:

```kotlin
@Test
fun testTestForAny() {
  val property: (Int) -> Unit = { i ->
    if (i < 0) throw AssertionError("$i")
  }
  var attempts = 0
  val failure = assertFailsWith<PropertyFailedException> {
    testForAny(Arb.int) {
      attempts += 1
      property(it)
    }
  }
  val failedSample = failure.sample as Int
  assertTrue(failure.cause is AssertionError)
  assertEquals("$failedSample", failure.cause?.message)
  assertEquals(attempts, failure.attempt)
}
```

Green:

```kotlin
fun <A> testForAny(aa: Arb<A>, seed: Long? = null, property: (A) -> Unit) =
  forAny(aa, seed) { a->
    property(a)
    true
  }
```

Refactor: I could reuse some lines between the two functions that test how the property based tests fail, but the resulting code is too much difficult to grasp. 

