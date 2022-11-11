---
layout: page
title: Series
---

## Introduction to testing

A series of articles that introduce automated testing from the very beginning. What is an automated test? Do we test the same way in the presence of persistent state? What about other side effects?

- [What is an automated test, again?](/2022-05-27-what-is-an-automated-test-again.html)
- [Testing and persistent state](/2022-06-17-testing-and-persistent-state.html)
- [Testing other side effects](/2022-07-08-testing-other-side-effects.html)

## Property Based Testing: Shrinking

This series focuses on one particular aspect of some Property Based Testing libraries: Value shrinking.

- [Part1: Introduction](/2022-08-26-pbt-shrinking-part1.html)
- [Part 2: Shrinking Functions](/2022-09-13-pbt-shrinking-part2.html)

## Writing a Property Based Testing Library in Kotlin

In which we write a Property Based Testing library from scratch in Kotlin using a TDD approach.

- [Part 1: Introduction](/2022-10-04-writing-a-pbt-ibrary-1.html)
- [Part 2: Primitives, nullable, product & mapping](/2022-10-14-writing-a-pbt-ibrary-2.html)
- [Part 3: Reproducibility of failed properties](/2022-10-25-writing-a-pbt-ibrary-3.html)

## Writing a Parser Combinator Library in Scala 3

This time we aim to write a combinator parser library from scratch in Scala 3, like the famous [Red book](https://www.manning.com/books/functional-programming-in-scala) does. But instead of applying algebraic design, we'll use a traditional TDD while developing a Json parser and will be creating abstractions, the Parser Combinator Library, during the refactor phases.

- [Part 1: Introduction to Parsing](/2022-11-11-writing-a-parser-combinator-library-1.html)
