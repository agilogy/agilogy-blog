---
layout: kotlin-post
title:  "Otra introduccion a la programacion funcional - Parte 1: Definición"
date:   2021-04-15 19:01:57 +0200
categories: kotlin,fp
---

{::options syntax_highlighter="nil" /}


La Programación Funcional, en adelante PF, como el nombre indica, es una práctica de programación y diseño de software consistente en utilizar funciones. Quien lea tal definición obvia podría pensar que todo el mundo usa funciones, cuando programa, entendiendo la palabra función como un sinónimo de procedimiento (_procedure_), rutina o subrutina o, en orientación a objetos, método. La diferencia radica en la definición de _función_ que usamos en Programación Funcional.

En PF, usamos la palabra **función** con una definición parecida a la de función matemática:

> Una función es una relación entre un conjunto A, llamado dominio, y un conjunto B, llamado codominio, tal que cada elemento de A, sin excepción, tiene asociado uno y solo un elemento de B

### Funciones

Para poder aplicar este concepto a un lenguaje de programación como Kotlin, es necesario asociar a cada concepto matemático algún concepto en nuestro espacio.

A modo de función matemática, usaremos las funciones de nuestro lenguaje. El dominio será el posible conjunto de valores de los argumentos de la función y el codominio será el posible conjunto de valores del resultado.

Por ejemplo:

```kotlin
fun inc(i: Int): Int = TODO()
```


En PF diremos que `inc` es una función. El domino será el conjunto de todos los valores de `Int` posibles y el codominio, el mismo conjunto.

También podremos considerar, claro está, funciones Kotlin de más de un parámetro:

```kotlin
fun sum(a: Int, b: Int): Int = TODO()
fun sum2(a: Pair<Int, Int>): Int = TODO()
```


En este caso, la función `sum` tendrá como dominio `Int x Int`, esto es, todas las posibles combinaciones de dos enteros. Nótese que `sum2` tendrá el mismo dominio exacto.

Por último, ¿cuál es el dominio en términos matemáticos de una función que no tiene parámetros? ¿Y el codominio de una función que retorna `Unit`? Ambas preguntas están relacionadas.

Una forma de verlo es preguntarnos, de cuántas maneras distintas podemos llamar a una función que no tiene parámetros. Puesto que podemos, efectivamente, llamarla, no son cero maneras. Solo hay una, en realidad. De forma simétrica, una función que devuelva `Unsit` (`void` en Java), puede, efectivamente, retornar y, por lo tanto, no tiene cero posibles formas de retornar si no una. En Kotlin, precisamente, el tipo llamado `Unit` es un tipo del que solo hay (y solo puede haber) una instancia, también llamada `Unit`. Por lo tanto, el dominio de una función sin parámetros es un único valor, `Unit`, y el codominio de una función que retorna `Unit`es el único valor de ese tipo.

Pero para que cumplan con la definición matemática de función, nuestras funciones kotlin deben tener ciertas características. En particular, tienen que ser:

- Deterministas
- Totales
- Libres de efectos

### Determinista

Una función matemática `f` relaciona cada elemento del dominio con un elemento del codominio. Por lo tanto, para un elemento del dominio `x`, cada vez que nos preguntamos por `f(x)` siempre obtenemos el  mismo resultado. Decimos que la función es determinista.

Pero las funciones Kotlin no tienen un resultado asociado a cada posible combinación de argumentos, si no que computan el resutlado cada vez. Por lo tanto, algunas de ellas, **no** son deterministas:

```kotlin
val now = System.currentTimeMillis()
var a: Int = 0
fun incrementA(amount: Int): Int {
  a = a + amount
  return a
}
val response = System.in.readlLine()
```

`System.currentTimeMillis()` no es determinista, porque si la invocamos más de una vez con los mismos argumentos (`Unit`),  si lo hacemos en un espacio de más de un milisegundo, nos retornará resultados distintos. Es decir, un mismo elemento del dominio tendría asociados distintos elementos del codominio en función del momento en que hagamos la computación.

De forma similar, `incrementA`, para un mismo argumento, retornará un valor distinto a cada computación, puesto que estará, cada vez, cambiando el valor de `a`. Y  `readLine` leerá de la entrada estándar y retornará, a cada computación, un resultado potencialmente (y probablemente) distinto.

### Total

Según la definición matemática de función, cada elemento del dominio tiene asociado un y solo un elemento del codominio. En particular, no puede pasar, que para un cierto elemento del dominio no tengamos valor. `f(x)` es un valor para cualquier elemento de `x`.

Con el _mapeo_ que hemos hecho de los conceptos matemáticos a funciones Kotlin, pero, no todas las funciones Kotlin son totales:

```kotlin
fun no3Please(i: Int): Int = if(i == 3) throw Exception("No!!!") else i + 1
```

La función kotlin `no3Please` es determinista, puesto que para un mismo argumento siempre produce el mismo resultado. Pero para el valor del dominio `3`, en nuestra asociación de codominio de las funciones Kotlin, no tiene ningún valor asociado.

Nota: Podríamos haber dfinido el codominio de una función Kotlin como el conjunto de valores posibles del tipo de retorno más el conjunto de posibles valor de excepción posibles. En tal caso, podríamos considerar esta función total. Pero tal definición sería poco práctica a la hora de usar las funciones, puesto que tendríamos que encapsular cada llamada a función en un `try...catch` o equivalente y tratar todos los posibles valores de retorno y excepciones.

Nota 2: Una función que, sencillamente, no acabe nunca, por ejemplo, que entre en un bucle infinito, tampoco sería total. Tales funciones no son deseables en PR pero tampoco los son en ningún otro paradigma.

Aunque en PF querremos usar funciones totales, usaremos una definición pragmática, más que matemática, de totalidad. Consideraremos que una función es total si no es razonable pensar que lance excepciones en su funcionamiento normal. Pero habrá algunas excepciones (valga la redundancia) que admitiremos; como mínimo, consideraremos que en cualquier momento se podría producir un `Error` en la máquina virtual Java, como por ejemplo un `OutOfMemoryException` que haga que una función lance una excepción y no por ello la consideraremos no total.

### Pura

Una función matemática és una relación entre dos conjuntos de elementos. `f(x)` es un valor, no un programa que computa un valor. Por lo tanto, si `f(x) = 3` tanto da escribir `f(x)` como escribir `3`. Estaríamos refiriéndonos al mismo valor. Decimos que la función no tiene ningún efecto colateral. Que es pura.

Pero no todas las funciones Kotlin son puras.

```kotlin
System.out.println("Hello world!")
```

La función `println` es determinista, puesto que siempre que la invocamos retorna el mismo valor, `Unit`. Podríamos decir que es una función total (o casi), porque no suele fallar. Pero, en todo caso, no es pura, puesto que cada vez que la computamos produce un resultado observable; por ejemplo, no es lo mismo invocarla una vez que hacerlo 100.000 veces.

Como en el caso de las funciones totales, en PF tendremos una definición de pureza no absoluta. Toda computación es observable, puesto que puede demorarse un tiempo, puede adquirir memoria y luego liberarla, puede calentar el núcleo en el que se calcula... Pero consideraremos puras aquellas funciones que no tienen otros efectos observables que la computación del valor de retorno en sí. 

### Resumen

La Programación Funcional consiste en el diseño y programación mediante funciones de nuestro lenguaje que:

1. Son deterministas: Para una misma combinación de argumentos siempre dan el mismo resultado
2. Son totales: Siempre acaban retornando un resultado del tipo indicado, sin lanzar excepciones
3. Son puras: No tienen efectos observables

Pero, ¿por qué querríamos programar de esta manera? Y, es más, ¿es siquiera deseable programar de esta manera?. ¿Qué utilidad tendría un programa que solo evalúa funciones que no tienen resultados observables?

Lo veremos en la segunda parte: [Motivación](Otra introducción más a la Programación Funcional - Parte 2 - Motivación.md).

