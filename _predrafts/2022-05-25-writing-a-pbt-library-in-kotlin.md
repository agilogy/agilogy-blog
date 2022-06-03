---
layout: kotlin-post
title:  "Writing a Property Based Testing library in Kotlin"
author: "Jordi Pradel"
categories: kotlin,testing,databases
---

{::options syntax_highlighter="nil" /}

This is an idea for a long series of blog posts where we write a PBT library in Kotlin. It comes from our experiences at Lifullconnect using Kotest and how it lacked a couple of interesting features we wanted, like testing until some coverage is reached or shrinking thoroughfully.

The inspiration could be taken from this excellent open source projects:

- [Kotest itself, of course](https://kotest.io/docs/proptest/property-based-testing.html)
- [Hypotesis](https://hypothesis.works/), a Python library which proclames to be a modern implementation of the concept. It has a really nice blog where they talk about lots of interesting concepts
- [Quickcheck](https://hackage.haskell.org/package/QuickCheck), the original property based testing library in Haskell
- [Hedgehog](https://hedgehog.qa/), a newer Haskell library in which blog I first read about [integrated vs manual shrinking](https://www.well-typed.com/blog/2019/05/integrated-shrinking/)
- [Others](https://hypothesis.works/articles/quickcheck-in-every-language/)