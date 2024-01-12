---

layout: post
title: Writing a Property Based Testing library in Kotlin, a Journey (part 1)
author: Jordi Pradel
categories: [kotlin,propertybasedtesting,pbt,testing,design]
description: >-
  Let's write a Property Based Testing library in Kotlin and see what happens!
---

I feel like doing that: writing a property based testing library. I've been blogging about property based testing in the past few weeks. In particular, about value shrinking. You can find the articles [here](./2022-08-26-pbt-shrinking-part1.html) and [here](./2022-09-13-pbt-shrinking-part2.html). The idea was to talk about the general concept but still show it in real(ish) code. At the same time, I wanted to avoid talking specifically about [Kotest](https://kotest.io/), [Scalatest](https://www.scalatest.org/) or any other library. Not because they are'nt amazing (they indeed are) but because they may be daunting and full-featured, which could be distracting to the purposes of my intent.

But now I'm in the mood for writing an actual property based testing library. Not one you will use in real projects, but one I can use to learn (and hopefully show, explain or teach) something about property based testing. Furthermore through my experience with those libraries, I've seen things I'd like to improve. Why not try my best at it?

![Let's do this!](../assets/img/letsDoThis.gif){:.figcaption}

So... let's do this! Let's write a property based testing library from scracth, in Kotlin, and tell the world about what I learn in the way...

You may already know about property based testing and maybe even used it. You may as well have read my previous blog posts about shrinking. Or property based testing may be a new concept to you. I hope whatever your situation is, this will be an interesting read, as we dive into such an amazing exercise.

## Property based testing: an introduction

I'm not goint to lie here. There are plenty of good introductory articles to property based testing, I'm in a hurry, I'm lazy and I don't want to write a lengthy explanation. So let's go direct to the point.

Our statement will be: We want to generate hundreds or thousands of random tests cases automatically with which to test our software instead of testing using hardcoded examples. Whenever our library finds a test case that fails, we want it to search for the simplest test case that still fails, and provide a clear, concise error message about what failed.

Easy peasy. So, if you are testing a nice `sum(a:Int, b:Int): Int` function,  instead of writing a test like...

```kotlin
val a = 5
val b = 9
assertEquals(14, sum(a, b))
```

You'd write something _like_{:.sidenote-number} _I know, I know... Bear with me and this ugly design. I just try to avoid spoiling the nice design we'll use just a couple of paragraphs below..._{:.sidenote}:

```kotlin
testManyTimes {
  val a = someRandomInt()
  val b = someRandomInt()
  assertEquals(`???`, sum(a, b))
}
```

But what value do we use for `???`{:.sidenote-number} _Why not `assertEquals(a + b, sum(a, b)`? -  you may say... Well, because that would mean, basically duplicating the implementation of the function under test in your test code. Which would have the classical DRY violations flaws and, worst of all, it would only test that 2 probably buggy implementations behave the same way._{:.sidenote}? 

When you use random data for test inputs and initial states, you get results that you can't foresee. Therefore, you can't write a test that expects a particular result ([or end state](./2022-06-17-testing-and-persistent-state.html)). The assertions you need to do depend on the test data randomly generated. We say you are checking properties.

Here you have an example of one such property:

> For any integer number i, sum(i, 0) = i

## Let's code!

How would we code a simple property like the one above? Clearly not with the `testManyTimes` and `someRandomInt` names I used above. We need:

- A value that represents "any integer number". We'll call it `randomInt`.
- A function that given such value returns wether it satisfies the desired property or not

So let's go with this naming:

```kotlin
forAny(randomInt){ i -> sum(i, 0) == i }
```

We could define one such function like _this_{:.sidenote-number} _I'm assuming a certain degree of imperative programming here: The function forAny will throw if there is a test failure. We could of course have it return a result functionally, but I prefer to keep things more familiar to more people._{:.sidenote}:

```kotlin
fun forAny(r: RandomInt, property: (Int) -> Boolean): Unit
```

I don't know about you, but this is asking me to generalize to other types than `Int`:

```kotlin
fun <A> forAny(r: Random<A>, property: (A) -> Boolean): Unit
```

Unfortunately, `Random` is the name of a class in `kotlin.random` that is used to... generate random numbers. I'd prefer to use a different name. The usual name for such a thing in property based testing is `Arbitrary` or `Arb`, for short. So, let's do some renaming:

```kotlin
fun <A> forAny(a: Arb<A>, property: (A) -> Boolean): Unit
```

Let's try to implement this `forAny` function. We want to test, let's say, 100 test cases generated by `Arb`:

```kotlin
fun <A> forAny(a: Arb<A>, property: (A) -> Boolean) {
    (1..100).forEach { attemptNumber ->
        val sample = a.generate()
        if (!property(sample)) 
          throw PropertyFailedException(attemptNumber,sample)
    }
}
```

So, we found out we need `Arb<A>` to implement  `generate()`{:.sidenote-number} _I added a companion object so that we can later add extension functions and values to it, see below._{:.sidenote}:

```kotlin
interface Arb<A> {
    fun generate(): A
    companion object
}
```

There are, of course, several important _limitations_{:.sidenote-number}_Some examples of such limitations: We would like to be able to provide a seed that makes our random values reproducible, we'd like to have better error messages, we'd like to be able to configure how many iterations we want on each property we check, we will want the library to [simplify test cases that fail to provide the simplest value that still fails](./2022-08-26-pbt-shrinking-part1.html), etc._{:.sidenote} in this implementation, but we want to start with something we can run as soon as possible and iterate from there.

## Generating arbitrary integers

So, to check our initial property, `forAny(arbInt){ i -> sum(i, 0) == i }`, we need an `Arb<Int>`, a generator of arbitrary `Int` values. If you know a bit about the Kotlin (or Java) way of generating random values it is not complicated. To make it easier to find using our IDE/editor auto-complete, we will add this `Arb` value as an extension to `Arb` companion object:

```kotlin
val Arb.Companion.int get() = object: Arb<Int>{
    override fun generate(): Int = kotlin.random.Random.nextInt()
}
```

## Finally checking some properties!

Now, everything is in place to actually _test_{:.sidenote-number}_We are using `kotlin.test` here, but any testing library/framework can work with our library, as it only needs to mark a test failed when a `PropertyFailedException` is thrown._{:.sidenote} some properties on `Int`s:

```kotlin
@Test
fun testSum0() = forAny(Arb.int) { i -> sum(i, 0) == i }
```

✅ Green!

What about finding a test case that fails? We'll use a property that is not true for the sake of demonstration purposes, but that would be what you would get if you were testing a property of your system and found a bug:

```kotlin
@Test
fun testDoubleIsGreater() = forAny(Arb.int) { i -> sum(i, i) >= i }
```

🔴 Property failed at attempt 3 with sample 2018188761

```console
com.agilogy.wapbtl.PropertyFailedException: Property failed at attempt 3 with sample 2018188761
	at app//com.agilogy.wapbtl.ForAnyKt.forAny(forAny.kt:12)
	at app//com.agilogy.wapbtl.ForAnyIntTest.testDoubleIsGreater(ForAnyIntTest.kt:14)
	at java.base@11.0.13/jdk.internal.reflect.NativeMethodAccessorImpl.invoke0(Native Method)
```

## Testing a testing library

So far so good... But, hey, I just realized I write automated tests for everything I develop. A property based testing library will be no exeption. So, I'd like to write a test about how a failed property check throws an exception:

```kotlin
@Test
fun testDoubleIsGreater() =
  assertFailsWith<PropertyFailedException> {  
    forAny(Arb.int) { i -> sum(i, i) >= i } 
  }
```

But this seems not enough... Not any `PropertyFailedException` is ok. At least, we would like to check that _the sample_{:.sidenote-number}_Unfortunately, Kotlin does not allow us to define a parameterized class that extends `Exception` and, therefore, the `sample` in our `PropertyFailedException` is of type `Any?`. That's the reason for that ugly cast in the code below._{:.sidenote} we get returned effectively fails our property check. As I'll be using the property `{ i -> i + i >= i }` twice, I extracted a value for it:

```kotlin
@Test
fun testDoubleIsGreater() {
    val property: (Int) -> Boolean =  { i -> sum(i, i) >= i }
    val failure = assertFailsWith<PropertyFailedException> {
        forAny(Arb.int, property)
    }
    val failedSample = failure.sample as Int
    assertFalse { property(failedSample) }
}
```

## Conclusion

So we created a minimalist property based testing library that is capable of testing properties of `Int` values. We implemented it in under 30 lines of code (without relying to magic one-liners). I hope this dissipates some magic feeling arround property based testing.

On top of that, we started writing tests of our property based testing library. I have the intuition that testing a library that generates random values will soon get quite complicated. But, hey, if it were easy it wouldn't be fun!

At the same time, we uncovered several limitations of our property testing function. And we are only capable, so far, of testing properties on Int values. 

You can see the current version of our library at [https://github.com/agile-jordi/wapbtl/tree/part1](https://github.com/agile-jordi/wapbtl/tree/part1).

Will our intrepid developers overcome such limitations? Stay tuned!

![Batman Robin GIF - Batman Robin Old School - Descubre & Comparte GIFs](../assets/img/same-bat-channel.png)

## All articles in the series

1. [Writing a property based testing library, part 1](./2022-10-04-writing-a-pbt-ibrary-1.html)
2. [Writing a property based testing library, part 2](./2022-10-14-writing-a-pbt-ibrary-2.html)
3. [Writing a property based testing library, part 3](./2022-10-25-writing-a-pbt-ibrary-3.html)
4. [Writing a property based testing library, part 4](./2024-01-12-writing-a-pbt-library-4-housekeeping.html)
