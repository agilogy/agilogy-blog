---
layout: kotlin-post
title:  "Blogging about Kotlin"
author: "Jordi Pradel"
categories: kotlin
---

{::options syntax_highlighter="nil" /}

This will be a short one. Have you read any of my [recent](2022-05-20-what-is-an-automated-test-again.html) [blog posts](2022-05-23-testing-and-persistent-state.html) [about testing](2022-05-23-testing-other-side-effects.html)? In this one I'll explain how we use those fancy runnable and editable examples.

This blog, like many more, is built with a static site generator. Some reasons we use that, in no particular order, are that we just want to publish documents, we hate our blogs being hacked and we love Markdown. In our case it is [Jekyll](https://jekyllrb.com/), because it is hugely popular, with plenty of themes to choose from and many recipes you can follow to do simple things.

But we wanted our code to shine. Indeed, one of our most loved t-shirts proclaims: "In code we trust".

In Markdown, you can write code fences like this:

<pre>
  ```kotlin
  fun sum(a: Int, b: Int): Int = a + b
  ```
</pre>
That's already nice in most Markdown environments, including Jekyll and my editor of choice, which happens to be the wonderful [Typora for Mac](https://typora.io/). In fact, as I write this, I see Kotlin samples like this:

<img align="left" src="../assets/kotlin-in-typora.png" alt="kotlin-in-typora" style="zoom:50%;" />

But when I discovered I could have the fancy executable (🥹) and even editable (🤩) examples in our own blog, like the excellent [Kotlin documentation](https://kotlinlang.org/docs/coroutines-basics.html) has, I wanted them badly!!

Those examples, and the ones in this blog, are powered by [kotlin-playground](https://github.com/JetBrains/kotlin-playground), an open source project by Jetbrains themselves to just do that.

But I'm too fond of my Markdown to start writing `<code>` blocks in it... and Kotlin Playground controls the appearence, target platform and other details of your code blocks by setting atttributes to your code blocks. I just didn't want code blocks, but just Markdown code fences with triple backtics.

So, how do we do it?

- [ ] TO-DO

So, this...

<pre>
{: data-runnableIn='js'}
```kotlin
fun main() {
//sampleStart
fun sum(a: Int, b: Int): Int = a + b
print(sum(-1, 8))
//sampleEnd
}
```
</pre>

...becomes this:

{: data-runnableIn='js'}
```kotlin
fun main() {
//sampleStart
fun sum(a: Int, b: Int): Int = a + b
print(sum(-1, 8))
//sampleEnd
}
```

While this:

<pre>

```kotlin
fun sum(a: Int, b: Int): Int =  a + b
```
</pre>

Is shown like this:

```kotlin
fun sum(a: Int, b: Int): Int =  a + b
```

