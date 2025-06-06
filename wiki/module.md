---
layout: page
title: Module
---



A **module** is a set of procedures grouped by modular design, which tries to subdivide the whole system into such modules so that they can be independently created, modified, replaced or exchanged with other modules or different systems.

## Modules from 0

Let's imagine we just invented programming. We have `if`, `while`, data structures, variables, mathematical operations... 

Se start building small problems and all is good. But when we start to build bigger programs, we realize that we need to be able to reuse parts of the program. We have many places where we look for a value in a collection of values, for example, and we don't want to program that search every single time. So we invent... `goto`. Yeah... ok, we invent `goto`, then we realize it was a huge mistake, and then we invent [procedures](procedure).

Now armed with our shiny new tool, we can divide our huge problem into smaller problems. But sooner than later we start to see some relations between our procedures. If we have a bird's eye view of which procedures use what other procedures, we can see something like this:

<img src="../assets/img/procedure-dependencies.jpg" alt="Procedure dependencies graph" style="zoom:35%;" />

Naturally, some clusters of procedures appear that have few dependencies to other procedures. And we realize that's good. Now, when working on one procedure of our system, we can focus on it and its "cluster" without having to take every other procedure in the system into account.

If we realize that, we can start grouping procedures on purpose to make our work easier. We can now not just trie to have groups of procedure **decoupled** from other groups, but we can also try to make them **cohesive** by giving each group a single, well-defined purpose. So we make these groups explicit in our programming language by _inventing_ **modules**.

## Modules in Object Oriented languages

### Static modules in Java

Let's talk about Java. Java is an object oriented language where (almost) everything is an object. In fact, everything is an object except `null`, primitive values (integers, chars, booleans, etc.)... and some other things (like methods or classes). As we all know, objects are instances of classes. So, in Java, every procedure is defined inside a class.

Although Java classes can be grouped in packages, packages can't contain procedures. So, no, a package is not our direct implementation of a module. What is one, then?

A module can be implemented in Java as a class with just static methods. To enforce its module nature we can:

- Make the class `final` so no other class tries to extend it and use it as if it was an usual class that you can inherit from.
- Make the class constructor `private` so no other part of the program can use it as if it was an usual class with instances and attributes.
- Define `public static` methods for procedures we want to make available to other modules, but `private static` methods for procedures we just want to have available internally to the module.
- Make sure we don't define any (mutable) attribute. In fact, immutable values will only act as constants and may either be private or public as well.

An example static module in Java:

```java
package com.agilogy.wiki.examples;
public final class CollectionsUtils {
  private CollectionsUtils() {}
  public static <A> Set<A> diff(final Set<A> s1, final Set<A> s2) {...}
}
```

### Static modules in Kotlin, Scala et alter

Other JVM languages like Kotlin or Scala allow you to define procedures directly in a package, without any class. In fact, at runtime they will represent those modules as methods in an instance created by their runtimes or by static methods in a class synthesized by their compilers.

An example module in Kotlin:

```kotlin
package com.agilogy.wiki.examples;
fun <A> diff(s1: Set<A>, s2: Set<A>): Set<A> = ...
```

### Instance modules







