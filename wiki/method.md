---
layout: page
title: Method
---

A software **[method](https://en.wikipedia.org/wiki/Method_(computer_programming))** is a procedure associated with an object. What this actually means is that every method has a special parameter (usually called *this* or *self* ) whose type is the type of the object.

An **[object](https://en.wikipedia.org/wiki/Object_(computer_science))** is a data structure containing variables (that hold data or other objects) and methods. These variables and methods are collectively called **members**.

For the sake of software design, a method can be seen just as a particular case of a procedure:

- Given a class `BirthDate`, an instance of it, and an invocation of one of its methods, here expressed in Java:

```java
class BirthDate {
  private final LocalDate date;

  public BirthDate(LocalDate date) {
    this.date = date;
  }

  public int getAge(LocalDate on) { ... }
}
var birthDate = new BirthDate(LocalDate.of(1980, 1, 1));
var result = birthDate.getAge(LocalDate.of(2024,4,19))
```

- An equivalent procedural implementation of the method `getAge` would be:

```java
class BirthDate {
  private final LocalDate date;

  public BirthDate(LocalDate date) {
    this.date = date;
  }
}

public int getAge(BirthDate self, LocalDate on) { ... }

var birthDate = new BirthDate(LocalDate.of(1980, 1, 1));
var result = getAge(birthDate, LocalDate.of(2024,4,19))
```

