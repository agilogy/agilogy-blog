---

layout: post
title: Writing a Property Based Testing library in Kotlin, a Journey (part 3)
author: Jordi Pradel
categories: [kotlin,propertybasedtesting,pbt,testing,design,fp]
description: >-
  Our small property based testing library is working now. But whenever something goes wrong, we want the maximum usability, so that diagnosing (and therefore fixing) bugs is as easy as possible. One way we can make our lives easier is by providing a mechanism to re-run the test directly using the exact same example that was used in a previously failed test.
---

In our [previous](/2022-10-04-writing-a-pbt-ibrary-1.html) [posts](/2022-10-14-writing-a-pbt-ibrary-2.html) we developed a minimal property based testing (PBT) library capable of checking properties on primitive types, nullable types, tuples and types mapped from other types, giving us the possibility of testing properties of our programs and functions for many kinds of input values.

One of the (many) shortcoming of this small thing we created is in the reproducibility of failed tests. If you are checking a property for simple values like `forAny(Arb.int) { i -> i + i >= i }`  the outcome is quite informative:

```shell
Property failed at attempt 3 with sample -836667656
com.agilogy.wapbtl.PropertyFailedException: Property failed at attempt 3 with sample -836667656
	at app//com.agilogy.wapbtl.ForAnyKt.forAny$test(forAny.kt:14)
	at app//com.agilogy.wapbtl.ForAnyKt.forAny(forAny.kt:18)
	at app//com.agilogy.wapbtl.ForAnyKt.forAny$default(forAny.kt:9)
```

We have the sample that made our property fail. If we want to reproduce the failed test, we just need to write an example based test with that example. But... What if our sample is a more or less complex datatype whose `toString()` is not suitable for a copy & paste into Kotlin code? What if the test is not a one-liner and "simply" writing an example based test involves copying an important amount of lines?

What I would like is to be able to change a single line of code and, hop!, make our property based test just test the exact sample for which I got a failure.

## Randomness

Grab your ~~dice~~ <ins>instance of Random</ins> and let's dig into how randomness works...

![Roll The Dice GIFs - Get the best GIF on GIPHY](https://media1.giphy.com/media/VGoZVlR9naOZCiRLSy/giphy.gif)

As you probably already know, random values generation by computers is actually quite a complex topic. Long story short, Kotlin's `Random` generates random values using an, in fact, predictable function that takes a seed and returns an endless sequence of aparently random numbers. Give it the same seed and poof! randomness is gone: you'll get the same sequence of values. This would be dangerous if you were using pseudo-randomness for cryptogrhaphic purposes, but it is really useful for us.

So, what we need is to be able to seed our tests whenever we want to reproduce a failure.

## Red

Let's do this TDD style. That is, let's write the test first so that we design the feature by thinking how we would like to use it instead of thinking about how to implement it:

```kotlin
@Test
fun forAnySeedParameterShouldReproduceTheFailingTest() {
    val property: (Int) -> Boolean = { i -> i + i >= i }
    val failure = assertFailsWith<PropertyFailedException> {
        forAny(Arb.int, property = property)
    }
    var actualExecutionsWithSeed = 0
    val seededFailure = assertFailsWith<PropertyFailedException> {
        forAny(Arb.int, failure.seed) {
          actualExecutionsWithSeed++
          property(it)
        }
    }
    assertEquals(failure.sample, seededFailure.sample)
    assertEquals(failure.seed, seededFailure.seed)
    assertEquals(1, seededFailure.attempt)
    assertEquals(1, actualExecutionsWithSeed)  
}
```

So, whenever we get a `PropertyFailedException` we want to get a `seed`. And, `forAny` now will take an optional `seed` as an argument and will give us some guarantees:

- If we use the seed returned by a failure, the test will fail
- The sample (and seed) returned by this failure will be the same sample (and seed) of the original exception
- But this time, the failure will be found at the first attempt.

So now our `forAny` functions will have a signature like this one (here the one for one `Arb` argument):

```kotlin
fun <A> forAny(r: Arb<A>, seed: Long? = null, property: (A) -> Boolean): Unit
```

And in case of failure it will throw:

```kotlin
class PropertyFailedException(val attempt: Int, val sample: Any?, val seed: Long) : Exception(
    "Property failed at attempt $attempt with seed $seed, sample $sample"
)
```

## Green

Ok, now let's go for the green.

Our `Arbitrary` instances are currently using `kotlin.Random` like this:

```kotlin
val Arb.Companion.int: Arb<Int> get() = object : Arb<Int> {
        override fun generate(): Int = kotlin.random.Random.nextInt()
}
```

What does `kotlin.random.Random.nextInt()` do? If we look under the hood at the implementation of the standard library, we'll find:

```kotlin
package kotlin.random
public abstract class Random {
    // ...
    companion object Default : Random(), Serializable {
      // ...
      private val defaultRandom: Random = defaultPlatformRandom()
      override fun nextInt(): Int = defaultRandom.nextInt()
    }
```

There is an important amount of things going on here:

1. At initialization time, an instance of `defaultRandom` is created
2. When we execute `Random.nextInt()` it uses `defaultRandom` to generate an `Int`{:.sidenote-number}_I didn't know, but companion objects can have a name. Don't let that distract you. If the companion object of `Random` has a method `nextInt()` then you can use it as `Random.nextInt()` no matter what the name of the companion object is . See the [kotlin docs](https://kotlinlang.org/docs/object-declarations.html#companion-objects)._{:.sidenote}
3. As a (probably) different `Int` value is returned each time, some kind of state must have also changed in `defaultInt` each time we invoke `nextInt()`.

Initially, I naively assumed I could get the "current seed" out of such state and, therefore, implement our tests like this:

```kotlin
val seed = Random.getCurrentSeed() // <-- invented function, does not exist
val sample = r.generate()
val result = property(sample)
if (!result)
  throw PropertyFailedException(attemptNumber, seed, sample)

```

Unfortunately, I found no such function. Furthermore, like the name suggests, `defaultPlantformRandom()` is platform specific and you can't reason about the implementation used unless you throw the current platform (JVM, Javascript or Native) into the discussion.

But we have a function in the standard library to get a `Random` instance with a given seed:

```kotlin
public fun Random(seed: Long): Random = XorWowRandom(seed.toInt(), seed.shr(32).toInt())
```

This time, for some reason, the returned type is not dependant on the platform, but we get an `XorWowRandom` instance no matter the plantform. Again, looking inside it we can actually see its mutable state:

```kotlin
internal class XorWowRandom internal constructor(
    private var x: Int,
    private var y: Int,
    private var z: Int,
    private var w: Int,
    private var v: Int,
    private var addend: Int
) : Random() // ...
```

So, for each tests execution I need to create an instance of `Random` from a known seed, make our generators use that instance of `Random` and, in case of failure, inform about the seed I used. How do we generate such a seed? We could use the current time in milliseconds or we can simply use... `Random` (the default instance):

```kotlin
val seed = Random.nextLong()
val random = Random(seed)
val sample = r.generate(random)
val result = property(sample)
if (!result)
  throw PropertyFailedException(attemptNumber, seed, sample)
```

So our `Arbitrary` interface is now:

```kotlin
interface Arb<A> {
    fun generate(random: Random): A
    companion object
}
```

And for primitives we simply use the `Random` argument instead of the platform default `Random`:

```kotlin
val Arb.Companion.int: Arb<Int> get() = object : Arb<Int> {
        override fun generate(random: Random): Int = random.nextInt()
}
```

But what about combinators? Let's look at how `product2` ens up:

```kotlin
fun <A, B, Z> Arb.Companion.product2(
    a: Arb<A>, b: Arb<B>, f: (A, B) -> Z
): Arb<Z> =
    object : Arb<Z> {
        override fun generate(random: Random): Z = f(a.generate(random), b.generate(random))
    }
```

Although aparently simple, there are some interesting implications in this design. As `random` is mutable (like we already saw), this combinator uses it twice, mutating its state twice. And that is exactly what we want: given a seed, the combinator will generate always the same pair of values. And this is valid for any of our other combinators. Let's see some of them:

```kotlin
fun <A, B, C, Z> Arb.Companion.product3(
    a: Arb<A>, b: Arb<B>, c: Arb<C>, f: (A, B, C) -> Z
): Arb<Z> =
    object : Arb<Z> {
        override fun generate(random: Random): Z = f(a.generate(random), b.generate(random), c.generate(random))
    }

fun <A, B> Arb<A>.map(f: (A) -> B): Arb<B> = object: Arb<B>{
    override fun generate(random: Random): B = f(this@map.generate(random))
}
```

Finally, we need our `forAny` function  to accept an optional `seed` argument. If such a seed is provided it should just run one test with the samples generated by such seed:

```kotlin
fun <A> forAny(r: Arb<A>, seed: Long? = null, property: (A) -> Boolean) {
    if (seed == null) {
        (1..100).forEach { attemptNumber ->
            val currentSeed = Random.nextLong()
            val sample = r.generate(Random(currentSeed))
            val result = property(sample)
            if (!result)
                throw PropertyFailedException(attemptNumber, currentSeed, sample)
        }
    } else {
        val sample = r.generate(Random(seed))
        val result = property(sample)
        if (!result)
            throw PropertyFailedException(1, seed, sample)
    }

}
```

## Refactor

I can improve many things but, at least, let's get rid of the code repetition in `forAny`{:.sidenote-number} _I used a function definition inside the `forAny` function, which may be not that familiar to some readers. I like functions insde functions because they don't bloat the namespace of your class and they don't require visibility modifiers. I know I don't need to look at them when reasoning about any other function that the one they are defined in. But if you don't like them, simply define a new private function in your class and call it a day._{:.sidenote}:

```kotlin
fun <A> forAny(r: Arb<A>, seed: Long? = null, property: (A) -> Boolean,) {
    fun test(currentSeed: Long, attemptNumber: Int) {
        val sample = r.generate(Random(currentSeed))
        val result = property(sample)
        if (!result)
            throw PropertyFailedException(attemptNumber, currentSeed, sample)
    }
    if (seed == null) {
        (1..100).forEach { attemptNumber ->
            test(Random.nextLong(), attemptNumber)
        }
    } else {
        test(seed, 1)
    }
}
```


## Conclusion

So, that's it! Now, whenever you get a test failure, if you want to run it again after some bug fixing attempt or you need to debug it, you simply look for the seed returned by the error message (let's say its `123456L`) and replace `forAny(arb, property)` with:

```kotlin
forAny(arb, 123456L, property)
```

You can see the current version of our library at [https://github.com/agile-jordi/wapbtl/tree/part3](https://github.com/agile-jordi/wapbtl/tree/part3).


## All articles in the series

1. [Writing a property based testing library, part 1](./2022-10-04-writing-a-pbt-ibrary-1.html)
2. [Writing a property based testing library, part 2](./2022-10-14-writing-a-pbt-ibrary-2.html)
3. [Writing a property based testing library, part 3](./2022-10-25-writing-a-pbt-ibrary-3.html)
4. [Writing a property based testing library, part 4](./2024-01-12-writing-a-pbt-library-4-housekeeping.html)





