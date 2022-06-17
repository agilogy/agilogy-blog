---

layout: post
title: Writing a Property Based Testing library in Kotlin, a Journey (part 2)
author: Jordi Pradel
categories: [kotlin,propertybasedtesting,pbt,testing,design]
description: >-
  Let's write a Property Based Testing library in Koglin and see what happens!
---

In our [previous post](/2022-07-01-writing-a-pbt-ibrary-1.html) we developed a minimal Property Based Testing library in Kotlin that was capable of testing properties of `Int` values. Amongst its limitations, I find its inhability to test properties on other types disturbing. So let's add some more `Arb` values to our beloved library.

## Simple types

We could start by adding `Arb` instances for some types for which `kotlin.random.Random` already knows how to generate random _values_{:.sidenote-number}_What about `Char` and `String`, aren't they simple? They aren't. Not if you work outside the ASCII limits. Which I do. Because I speak catalan, and we have things like `è` or `ç` or even `l·l`... and I work in projects that use asiatic languages which for us, poor lating alphabet users, are a complex fantasy._{:.sidenote}:

```kotlin
val Arb.Companion.long: Arb<Long> get() = object : Arb<Long> {
    override fun generate(): Long = kotlin.random.Random.nextLong()
}

val Arb.Companion.float: Arb<Float> get() = object: Arb<Float>{
    override fun generate(): Float = kotlin.random.Random.nextFloat()
}

val Arb.Companion.double: Arb<Double> get() = object: Arb<Double>{
    override fun generate(): Double = kotlin.random.Random.nextDouble()
}

val Arb.Companion.boolean: Arb<Boolean> get() = object: Arb<Boolean>{
    override fun generate(): Boolean = kotlin.random.Random.nextBoolean()
}
```

Studying `kotlin.random.Random` we can see it is also easy to generate random values within a range. So, let's add that:

```kotlin
fun Arb.Companion.int(range: IntRange): Arb<Int> = object : Arb<Int> {
    override fun generate(): Int = kotlin.random.Random.nextInt(range)
}
```

And so on...

## Nullable values

What about nullable types like `Int?` or `Float?`. We could build a nullable version of each `Arb` we have, but that would be tedious and repetitive. What we would like is to be able to convert an `Arb<A>` to an `Arb<A?>` for any given `A` .

Let's try it! We can even adjust the probability we want to get a null value: _We parameterize the type as <A: Any> so that you can't use `orNull` on already nullable types. That will avoid confusion, as applying multilpe times `orNull` would exagerate the probability fo null values being generated._{:.marginnote} 

```kotlin
fun <A : Any> Arb<A>.orNull(nullProbability: Double = 0.5): Arb<A?> =
  object : Arb<A?> {
    override fun generate(): A? =
      if (Random.nextDouble(0.0, 1.0) <= nullProbability) null
      else this@orNull.generate()
}
```



## Arbitrary pairs, triples and other tuples

Let's say I want to check a typical property, like the commutativity of the sum of integers:

> For any pair of ints a, b: a + b = b + a

In this example I need arbitrary values of type `Pair<Int, Int>`. Again, instead of thinking about concrete solutions every time we need one, let's generalize that to arbitrary values that are tuples of other types:

```kotlin
fun <A, B> Arb.Companion.pair(a: Arb<A>, b: Arb<B>): Arb<Pair<A, B>> =
    object : Arb<Pair<A, B>> {
        override fun generate(): Pair<A, B> = a.generate() to b.generate()
    }

fun <A, B, C> Arb.Companion.triple(
  a: Arb<A>, b: Arb<B>, c: Arb<C>
): Arb<Triple<A, B, C>> =
    object : Arb<Triple<A, B, C>> {
        override fun generate(): Triple<A, B, C> =
            Triple(a.generate(), b.generate(), c.generate())
    }
```

Of course, in the Kotlin tradition of **not** having tuples of arity greater than 3, we can add versions of this idea for whatever arity as long as we ask for a function to build the result:

```kotlin
fun <A, B, Z> Arb.Companion.product2(
  a: Arb<A>, b: Arb<B>, f: (A, B) -> Z
): Arb<Z> =
    object : Arb<Z> {
        override fun generate(): Z = f(a.generate(), b.generate())
    }

fun <A, B, C, Z> Arb.Companion.product3(
  a: Arb<A>, b: Arb<B>, c: Arb<C>, f: (A, B, C) -> Z
): Arb<Z> =
    object : Arb<Z> {
        override fun generate(): Z = 
          f(a.generate(), b.generate(), c.generate())
    }

fun <A, B, C, D, Z> Arb.Companion.product4(
    a: Arb<A>, b: Arb<B>, c: Arb<C>, d: Arb<D>, f: (A, B, C, D) -> Z
): Arb<Z> =
    object : Arb<Z> {
        override fun generate(): Z = 
          f(a.generate(), b.generate(), c.generate(), d.generate())
    }
```

And now we can see `pair` and `triple` as simple helpers over `product2` and `product3`:

```kotlin
fun <A, B> Arb.Companion.pair(a: Arb<A>, b: Arb<B>): Arb<Pair<A, B>> =
    product2(a, b, ::Pair)

fun <A, B, C> Arb.Companion.triple(
  a: Arb<A>, b: Arb<B>, c: Arb<C>
): Arb<Triple<A, B, C>> =
    product3(a, b, c, ::Triple)
```

Now we can test our commutativity:

```kotlin
@Test
fun testSumCommutativity() {
    forAny(Arb.pair(Arb.int, Arb.int)){ (a, b) -> a + b == b + a }
}
```

Looking at this example, it seems interesting to make `forAny` accept more than one `Arb` so that our user doesn't need to build a tuple to test properties over a number of values:

```kotlin
fun <A, B> forAny(a: Arb<A>, b: Arb<B>, property: (A, B) -> Boolean) =
    forAny(Arb.pair(a, b)){ (a, b) -> property(a,b) }
```

Unfortunately this approach builds an unnecessary `Pair` and is limited to arities 2 and 3. Let's try a different approach:

```kotlin
fun <A, B> forAny(a: Arb<A>, b: Arb<B>, property: (A, B) -> Boolean) =
    forAny(Arb.product2(a, b, property)){ it }

fun <A, B, C> forAny(a: Arb<A>, b: Arb<B>, c: Arb<C>, property: (A, B, C) -> Boolean) =
    forAny(Arb.product3(a, b, c, property)){ it }
```

Now we can use any arity we have a `productN` for.

Finally, our property would be:

```kotlin
@Test
fun testSumCommutativity() {
    forAny(Arb.int, Arb.int){ a, b -> a + b == b + a }
}
```


## Mapping...

Now let's say you have a nice `Enum` representing some important business type:

```kotlin
enum class DayOfWeek{
    Mon, Tue, Wed, Thu, Fri, Sat, Sun;
    fun next(days: Int): DayOfWeek = ...
}
```

And let's imagine we want to check some properties involving days of week. We may want to check that days of the week repeat after 7 days. Or we may want to check that we know how to write the day of the week in a String and read it afterwards. Whatever the property, we need an `Arb<DayOfWeek>`. 

We can build one by generating a random number between 0 and 6 and getting the enum value in that position:

```kotlin
fun Arb.Companion.dayOfWeek() = object : Arb<DayOfWeek> {
    override fun generate(): DayOfWeek {
        val i = kotlin.random.Random.nextInt(0..6)
        return DayOfWeek.values()[i]
    }
}
```

But it is a shame we repeated the generation of random integers. We already implemented that. Let's say we want to be able to apply `DayOfWeek.values()[i]` to whatever `i` is generated by `Arb.int`. Does that sound familiar? Not yet? Ok, let's call it `map`:

```kotlin
fun <A, B> Arb<A>.map(f: (A) -> B): Arb<B> = object: Arb<B>{
    override fun generate(): B = f(this@map.generate())
}
```

Now, we can rewrite our `dayOfWeek` `Arb` like this:

```kotlin
fun Arb.Companion.dayOfWeek() = Arb.int(0..6).map { DayOfWeek.values()[it] }
```

In fact, we can generalize further by providing a way to generate arbitrary values of any `Enum`. The trick is the function `enumValues<E>` that Kotlin provides. If you invoke it (with a type parameter which is an `Enum`) it will return all the values of the `Enum`. If you try, IntelliJ will complain that your function must be `inline` and your type param `reified`{:.sidenote-number}_If this sounds alien to you, you can learn more about inline functions and reified parameters in the excellent [Kotlin documentation](https://kotlinlang.org/docs/inline-functions.html#reified-type-parameters)._{:.sidenote}. Just `Alt+Enter` it!

```kotlin
inline fun <reified E : Enum<E>> Arb.Companion.enum(): Arb<E> {
    val values = enumValues<E>()
    return Arb.int(values.indices).map { values[it] }
}
```

## Conclusion

We added values and functions to get `Arb` instances of several types. Beyond _primitive_ `Arb` types we built by hand (like `Boolean`, `Int`, `Double` and so on), we started creating `Arb` **combinators**, functions that take `Arb` instances and maybe other parameters and return new `Arb` instances.

In particular, we first created a combinator `orNull()` that given an `Arb<A>` (where `A` is not nullable) returns an `Arb<A?>`. Then we saw how to create an `Arb` of pairs of types given a pair of `Arb`s of (possibly) different types. Finally we saw how to `map` over `Arb` instances to get an `Arb` that returns the result of applying a function to the result of the original `Arb`.

You can see the current version of our library at [https://github.com/agile-jordi/wapbtl/tree/part2](https://github.com/agile-jordi/wapbtl/tree/part2).
