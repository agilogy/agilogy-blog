---
layout: kotlin-post
title:  "Otra introduccion a la programacion funcional - Parte 2: Motivación"
date:   2021-04-15 19:01:57 +0200
categories: kotlin,fp
---

{::options syntax_highlighter="nil" /}

## Parte 2: Motivación

En la [primera parte](Otra introducción más a la Programación Funcional - Parte 1 - Definición.md) de esta serie de artículos vimos que la Programación Funcional, en adelante PF, consistía en la programación mediante funciones de nuestro lenguaje de programación razonablemente parecidas a las funciones matemáticas:

1. Deterministas: Para una misma combinación de argumentos siempre dan el mismo resultado
2. Totales: Siempre acaban retornando un resultado del tipo indicado, sin lanzar excepciones
3. Puras: No tienen efectos observables

Pero nos preguntábamos:

- ¿Por qué querríamos programar de esta manera? 
- ¿Qué utilidad tendría un programa que solo evalúa funciones que no tienen resultados observables?

Intentemos resolver la primera de estas preguntas. Para ello, empecemos por introducir un nuevo concepto, la transparencia referencial, y luego veamos cómo nos permite hacer razonamiento local y por qué es deseable.

### Transparencia referencial

En PF decimos que una expresión es [transparente referencialmente](https://en.wikipedia.org/wiki/Referential_transparency) si puede ser reemplazada por su valor correspondiente (y viceversa) sin cambiar el comportamiento del programa. Por la definición que dimos de función en la primera parte, toda invocación de una función en PF tiene esa propiedad.

Veamos un ejemplo:

{: data-runnableIn="js"}
```kotlin
fun main() = run{ //sampleStart
    fun sum(a: Int, b: Int) = a + b
    fun plusOne(i: Int): Int = i + 1
    val x = plusOne(12)
    sum(x, x)
//sampleEnd
}.let{println(it)}
```

Ambas funciones aquí definidas, `sum` y `plusOne` son deterministas, totales y puras. Por lo tanto, toda expresión que sea una invocación a dichas funciones, puede ser reemplazada por su valor en cualquier momento.

Así, por ejemplo, podríamos empezar por reemplazar `plusOne(12)` por su valor:

```kotlin
val x = 12 + 1
sum(x, x)
```

Y luego podríamos reemplazar `12 + 1` por su valor y `x`, a su vez, por su valor:

```kotlin
val x = 13
sum(13, 13)
```

Y entonces, podríamos sustituir `sum(13, 13)` por su valor (`13 + 13`) y esa expresión, a su turno, por su valor:

```kotlin
val x = 13
26
```

Pero, partiendo del punto inicial, podríamos haber decidio empezar por sustituir `x` por su valor:

```kotlin
val x = plusOne(12)
sum(plusOne(12), plusOne(12))
```

Luego podríamos sustituir el primer `plusOne(12)` por su valor (`12 + 1`) y esta expresión por su valor:

```kotlin
val x = plusOne(12)
sum(13, plusOne(12))
```

Luego podríamos sustituir el segundo `plusOne(12)` como el anterior:

```kotlin
val x = plusOne(12)
sum(13, 13)
```

Y llegaríamos al mismo resultado:

```kotlin
val x = 13
26
```

De hecho, hemos estado usando una sintaxis para la definición de funciones que invita a pensar en la sustitución de valores. Igual que `val x = 13`, escribimos `fun sum(a: Int, b: Int): Int = a + b`. Ese signo `=` no es casual. Expresa el hecho de que `sum(a, b)` es lo mismo que (es igual a) `a + b`. 

### Razonamiento local (_local reasoning_)



TODO: Como la transparencia referencial nos permite razonar solo en términos de lo que vemos

TODO: Por qué las funciones no deterministas, no totales o impuras no permiten tener transparencia referencial

### ### 



