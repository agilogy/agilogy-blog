---
layout: post
title: "A glimpse into the (near) future of functional programming in Kotlin with arrow-kt"
author: Jordi Pradel
categories: [kotlin,design,fp,arrowkt]
description: >-
  TODO()

---



In this article I'll share how functional programming in Kotlin with Arrow 2.0 and context receivers will be like. Although I will shortly introduce the concepts I don't pretend to deeply explain them but just to give a glimpse of the beauty of this particular combination of upcoming technologies. It doesn't matter whether you are an experienced functional programmer in some other language, you used prevous versions of Arrow-kt or you have just read a bit about pure functional-programming but you are not using it. I think you may like what's coming. And, if you are in the later group and you think functional programming is not for your team because it is difficult, I think Arrow 2.0 will help you change your mind.

Let's dig in!

But first, some personal context...

## Why are I am so excited about Arrow 2.0 and Kotlin context receivers?

I'm really interested in functional programming since I started using it, many years ago, in Scala. I've worked for years in pure functional codebases using the [typelevel ecosystem](https://typelevel.org/) and I found it powerful and simpler than most people think. Even though I'm the kind of developer that enjoys mathematical abstractions, the main selling point of functional programming for me (and the teams I helped adopting it) was not the abstraction itself, but the simplicity. Suddenly lot's of things are easier to reason about:

- Immutability allows me to do local reasoning in a way that is not possible in the presence of mutability
- Pure functions allow me to compose behaviour (e.g. retry exponentially any part of my program) in a way that is not possible in the presence of arbitrary side effects
- Functional error handling allow me to take control of those errors I want my code to be able to recover from. And I can do so guided by types.
- A pure functional concurrency library (e.g. [cats-effect](https://github.com/typelevel/cats-effect/)) allows me to handle concurrency at a so high level that the solutions are much simpler. That allowed me to optimize resource usage (e.g. by avoiding blocking threads and by handling cancellation properly) and save tons of money to my customers.

When I started writing Kotlin, I looked for an equivalent solution... but I found none. Well, there was [Arrow-kt](https://arrow-kt.io/), but it was not the right moment to start using it. Arrow started more or less as a literal translation of the typelevel stack to Kotlin. It used the abstractions typelevel used which, in turn, came from Haskell: the dreaded Monad and friends. But Kotlin lacking higher kinded types made the library really non-idiomatic, to say the least.

That has been changing in the recent months. Arrow [got rid of monads](https://arrow-kt.io/learn/design/receivers-flatmap/#no-monads-no-higher-kinded-types), that are not well-supported, and embraced an idiomatic programming style. And, in particular, it embraced suspend functions as the way to represent an effect, which allows us to get rid of wrarper types and do functional programming in a direct style. Furthermore, it brings a solution for the [composition of effects](https://arrow-kt.io/learn/design/receivers-flatmap/#composition-of-effects), which tends to be painful and suboptimal with monadic libraries.

For all these reasons I think Arrow 2.0 will make functional programming much more welcoming to developers and teams first aproaching it.

## Ideas

- Domain modeling: data classes + value classes
- Typed errors: Fail fast vs accumulation
- Dependency injection: constructor dependency injection + context injection (e.g. Connection)
- Closing resources in the presence of errors: Resource



## A time tracking application

## Domain modeling

Let's start by [domain modeling](https://arrow-kt.io/learn/design/domain-modeling/), that is, programming classes whose instances will represent domain objects in a high level of abstraction using the language of our domain.

Let's take a time entry. That is, the fact that yesterday I worked 8am to 10am on project "Agilogy school" at zone id "Europe/Madrid".

- We want immutability, which allows local reasoning. So we will use a data class.
- We want the type system to guide us and avoid bugs like using a user name as a project name. So we will use value classes for simpler types.

That's plain Kotlin, so:

```kotlin
data class TimeEntry(
    val developer: DeveloperId,
    val project: ProjectId,
    val range: ClosedRange<Instant>,
    val zoneId: ZoneId,
)
@JvmInline value class DeveloperId(val name: String)
@JvmInline value class ProjectId(val name: String)
```

As this is modeling a domain entity, it makes sense for certain domain logic to be coded in the entity class itself. We could be interested in the local date of the time entry or in its total duration:

```kotlin
data class TimeEntry(...) {
	val duration: Duration = (
    range.endInclusive.toEpochMilli() - range.start.toEpochMilli() + 1
  ).milliseconds
	val localDate: LocalDate = range.start.atZone(zoneId).toLocalDate() 
}
```

Now let's say we want to make illegal states unrepresentable. We want to be sure that having an instance of  `DeveloperId`, means we indeed have a valid developer name acording to our business rules. That makes our types tell us that whenever we get a value of such type, we can rest assured that the value is valid.

Taking `DeveloperId` as an example, we can achieve that by:

- Defining a function of type `(String) -> DeveloperId` that fails if the `String` is not a valid developer id
- Avoiding any other way of creating an instance of `DeveloperId` 

We can achieve the former by making the constructor private and defining an `operator invoke` function in the companion object:

```kotlin
@JvmInline
value class DeveloperId(val value: String){
    companion object {
        private val validDeveloperId = Regex("[0-9a-zA-Z_.]+")
        operator fun invoke(value: String): DeveloperId {
            require(validDeveloperId.matchEntire(value) != null) { "Illegal developer id" }
            return DeveloperId(value)
        }
    }
}
```

As for the later... Even though there is no way now to create an instance of `DeveloperId` from a bare `String` in a way that circumvents our invariant, we can still use the autogenerated `copy` method and do some nasty thing like `validDeveloperId.copy(value = "")` and we get an invalid `DeveloperId` that shouldn't be possible. Although [there is interest in a way to control that](https://youtrack.jetbrains.com/issue/KT-11914/Confusing-data-class-copy-with-private-constructor) the best solution so far is to trust in your team's discipline and not use `copy` or use the [NoCopy plugin](https://github.com/AhmedMourad0/no-copy).

### Error handling

In our programs there are two kinds of errors.

The first kind is the kind of errors you don't want to recover from. These are unexpected errors for which, apart from retrying, there is no other solution than  reporting them, possibly apologize to an end user with a generic "ops" message. The database may have dropped, there may be an unreacheable host or a needed external API is giving us 500 errors. We probably want our nice api or worker program to keep working and survive them hoping they don't keep occurring forever. But we don't need any other treatment. 

Then, there is the second kind of errors, which Arrow calls logical failures. Logical failures are situations not considered succesful in our domain but that we expect to handle somehow. Maybe the username the user provided is not valid, the password is not strong enough or a user with that username already exists. For this kind of errors we may want to inform the user of what is wrong specifically, not just with an "ops" error. Or, sometimes, we may have an alternative path for when one of those occur. 

For thi first kind of errors, exceptions are fine. They don't clutter our type signatures and they buble up to some generic handler that reports all of them the same way. But for logical failures we will use [Arrow's typed errors](https://arrow-kt.io/learn/typed-errors/working-with-typed-errors/). 

Let's imagine we have a web from through which an administrator can register new developers to our system:

```kotlin
data class Developer(
  val id: DeveloperId,
  val name: DeveloperName,
  val email: Email
)
@JvmInline
value class DeveloperName(val value: String){
    companion object {
        operator fun invoke(value: String): DeveloperName {
	          val trimmed = value.trim()
            require(trimmed.isNotEmpty()) { "Blank developer names are not allowed" }
            return DeveloperName(trimmed)
        }
    }
}
@JvmInline value class Email(val name: String) { ... }
```

Assuming the DeveloperId is generated by our system, we expect our system to validate name and email and provide an error message for each one that fails. If none fails, it should go ahead and register the new developer.

Having `DeveloperName.invoke` throw an exception when it is not valid is not helping us control such situation. We will need to `try...catch` and we will need to check the `invoke` implementation to see what exception to expect and how to handle it.

Enter `Raise` and Arrow's typed errors: 

```kotlin
@JvmInline
value class DeveloperName(val value: String){
    companion object {
        context(Raise<InvalidDeveloperName>)
        operator fun invoke(value: String): DeveloperName {
	          val trimmed = value.trim()
            ensure(trimmed.isNotEmpty()) { InvalidDeveloperName }
            return DeveloperName(trimmed)
        }
    }
}
```



