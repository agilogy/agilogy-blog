---
layout: post
title:  "Testing other side effects"
author: "Jordi Pradel"
categories: [kotlin,testing]
description: >-
  TO-DO
---

In our previous articles about testing we saw a nice [testing recipe](2022-05-27-what-is-an-automated-test-again.html), how to handle databases and [persistent state](2022-06-17-testing-and-persistent-state.html) in tests and how to [design for testability](2022-06-24-testing-other-side-effects.html) decoupling side effects from other parts of your function and using dependency injection.

But so far we have been testing pretty small units, like our nice `age` function. Today we will apply the very same ideas and principles to test something bigger.

Imagine we are developing a meeting room reservation system.

```kotlin


```