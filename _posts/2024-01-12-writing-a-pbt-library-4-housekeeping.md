---

layout: post
title: "Writing a Property Based Testing library in Kotlin, a Journey. Part 4: Housekeeping"
author: Jordi Pradel
categories: [kotlin,propertybasedtesting,pbt,testing,design,fp]
description: >-
  In this entry we retake the Property Based Testing series. But instead of talking about PBT I'll be blogging about the process of enhancing the current design of the library and upgrading its Gradle and Kotlin versions.
---

I've had some busy months since I last wrote anything for the blog. Let's start 2024 by retaking the blog. Today I rescue an entry that I had in progress. We'll do some housekeeping of the Property Based Library I was writing back in 2023.

In the previous articles in this series ([1](./2022-10-04-writing-a-pbt-ibrary-1.html), [2](./2022-10-14-writing-a-pbt-ibrary-2.html) and [3](./2022-10-21-writing-a-pbt-ibrary-3.html)) I was developing a property based testing library from scratch and blogging about the process. It turns out that such library actually exists as a companion repository you can follow while reading. It's [here](https://github.com/agile-jordi/wapbtl/tree/part4). So far all articles in the series were about property based testing themselves. But, at the same time, I'm blogging about the actual design of a library.

![Pulp Fiction Winston Wolf](../assets/img/winstonWolf.gif){:.figcaption}
_Let's start!_{:.figcaption}

As I was focusing on writing about PBT the library has accumulated some problems I'd like fixed. And you bet I'll be blogging about this too.

## Reorganizing tests

As I'm using the library to write this blog series, I'm actually programming (and running the tests) for the code I use in the blog. But some of those code fragments are actually usage examples (like `Int` tests, `DayOfWeek` and `Geometry`). Let's put all of those in a simple package `com.agilogy.wapbtl.examples` so that they are not mixed with actual tests of the library, that will be in `com.agilogy.wapbtl.test`. Examples should probably be in a different project in the multiproject build but I'm frankly not in the mood for a fight with Gradle to get that done. Not now.

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

When `forAny` takes more than one `Arg`, what would the sample be? We could use tuples and have a sample of type `Pair<A, B>` if we were given 2 args, and a `Triple<A, B, C>` if we were given 3. What if we want a `forAny` of 4 or more values? Coming from Scala I'd say bigger tuples (`Tuple4`, `Tuple5`...) would totally make sense here... even though they are not idiomatic in Kotlin. I could use a `List<Any?>` and put all samples in that list, but I hate to have something that poorly typed. So, lacking a better solution, I will go with the two tuples we already have. Any ideas are welcome here, if you want to tweet or toot (with a mention) or DM them. I'm [@jordipradel@fosstodon.org](https://fosstodon.org/@jordipradel) (Mastodon, preferred) and  [@agile_jordi](https://twitter.com/agile_jordi) (Twitter).

So now that we decided we expect a tuple, we can fix the bug. But, hey, I just did a quick retrospective, right? Don't let the gap grow bigger and fix the bug the way se should: by first reproducing it:

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

So, letting aside the ugly casts, we are testing that whenever a `forAny` that takes two `Arb<Int>` fails, it should return a `Pair<Int,Int>` as the failed sample, and that checking the property on those 2 values should fail. And, it fails. _Yay!_{:.sidenote-number} _Yes, yay! Because when you are writing a test you expect it to be useful. And a test that you write but never fails is giving you exactly 0 value._{:.sidenote} We are also testing what we already tested for the one arbitrary version of `forAny`, to make sure we didn't break the `attempt` result.

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

As is customary in testing libraries, we would like to treat an exception as a test failure. Therefore, we may have 3 possible outcomes of the evaluation of your property for a given example. Either the property successfully returns `true`, or it successfully returns `false` or it fails with an exception. We'll consider both returning `false` or throwing an exception a way of telling us the property does not abide.

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

## Having fun with fun interfaces

One more thing... So far, every time we define a new instance of `Arb` we go like this:

```kotlin
val Arb.Companion.float: Arb<Float>
    get() = object : Arb<Float> {
        override fun generate(random: Random): Float = 
          random.nextFloat()
    }
```

But you may know Kotlin has this nice feature called [functional interfaces](https://kotlinlang.org/docs/fun-interfaces.html). We only need to add the `fun` keyword to our interface:

```kotlin
fun interface Arb<A> {
    fun generate(random: Random): A

    companion object
}
```

And we can now simplify all those `object : Arb<...>` expressions like in the example below:

```kotlin
val Arb.Companion.float: Arb<Float>
    get() = Arb { random -> random.nextFloat() }
```

## Upgrading Gradle and libraries

Finally, since it's been quite long since I last worked on this library, some of its dependencies are a bit outdated. Let us fix that.

I'll start with Gradle. Acording to `./gradlew --version`, the project is currently using Gradle 7.3.3. What version should we upgrade to? Let's do some research:

- The latest Gradle version at the time of writing is [8.5](https://gradle.org/releases/) 
- The Kotlin Gradle Plugin latest supported Gradle version is 8.1.1 acording to [the documentation](https://kotlinlang.org/docs/gradle-configure-project.html#apply-the-plugin).
- But Ktor is using [8.4](https://github.com/ktorio/ktor/pull/3802)

So we'll use 8.4.

We could change files by hand, but there is already a Gradle task to upgrade the gradle wrapper:

```shell
$ gradle wrapper --gradle-version 8.4
...
$ git status
...
Changes not staged for commit:
        modified:   gradle/wrapper/gradle-wrapper.jar
        modified:   gradle/wrapper/gradle-wrapper.properties
        modified:   gradlew
        modified:   gradlew.bat
...
$ git commit -am "Upgrade Gradle to latest supported version"
```


Now we can upgrade the Kotlin Gradle Plugin to the [latest version](https://plugins.gradle.org/plugin/org.jetbrains.kotlin.android/1.9.22). For that, we need to change the corresponding line in `build.gradle.kts`:


```kotlin
kotlin("multiplatform") version "1.9.22"
```

But then, we'll find our build fails and, when fixed, emits some warnings. Here are some changes we need to do to `build.gradle.kts`:

- `cssSupport.enabled = true` is not supported anymore. We need to replace it with `cssSupport{enabled = true}`
- The Kotlin/JS Legacy compiler backend is deprecated. We need to replace `js(LEGACY)` with `js`.
- Variable `nativeTarget` is never used. I wanted a Kotlin multiplatform build so that the library can be used in any platform. But I don't want to spend time configuring native builds now, so I'll simply remove the build for those. We can add them later on if we want.


Furthermore, Kotlin 1.9.20 brought us [templates for multiplatform projects](https://kotlinlang.org/docs/whatsnew1920.html#template-for-configuring-multiplatform-projects). The neat result is that we can simply remove all the manual `sourceSets` configuration we had and replace it with just the configuration of the dependencies we need:

```kotlin
dependencies {
    commonTestImplementation(kotlin("test"))
}
```

## Recap

We made some maintenance tasks on our beloved Property Based Testing library. We reorganized packages to better distinguish between tests and examples. As a result of that, we improved some example tests and found a design failure that we fixed using TDD. We enhanced the usability of the library by adding explicit support to exceptions during tests. Finally, we upgraded both Gradle and Kotlin to the latest current versions.

## All articles in the series

1. [Writing a property based testing library, part 1](./2022-10-04-writing-a-pbt-ibrary-1.html)
2. [Writing a property based testing library, part 2](./2022-10-14-writing-a-pbt-ibrary-2.html)
3. [Writing a property based testing library, part 3](./2022-10-25-writing-a-pbt-ibrary-3.html)
4. [Writing a property based testing library, part 4](./2024-01-12-writing-a-pbt-library-4-housekeeping.html)

