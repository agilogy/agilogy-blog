---
layout: kotlin-post
title:  Testing the Agilogy way - a backog"
author: "Jordi Pradel"
categories: kotlin,testing
---

## Punts clau

- [x] Com s'escriu una prova automatitzada d'una funció pura?
- [ ] Les assercions: Què ens diuen quan fallen?
  - [ ] Feedback en cas de fallida d'una prova: Assercions clares, fallades clares
  - [ ] Estreatègies d'asserció: DSLs i coses així, assercions senzilles ( `assertTrue` i `assertEquals`) i macros o semblants
- [x] Com s'escriu una prova automatitzada d'un procediment (o component sw)
  - Estat inicial **conegut**: Res de bases de dades compartides, entorns on altres usuaris poden variar el resultat de la prova, _suites_ de proves que només passen si les proves s'executen en un ordre determinat...
  - Assercions sobre l'estat final
- [ ] Què és una _test suite_?
- [ ] Limitacions de les proves automatitzades: Què ha de fallar per a que no detectem un bug?
  - Cobertura de codi / de branques / d'_inputs_...
  - Doble bug: Proves errònies
- [ ] Com aïllar un component sw per a provar-lo aïlladament
  - Injecció de dependències
  - _Test doubles_
- [ ] Limitacions de _mocks_ / _stubs_
  - Com implementar un _mock_. Si no sabem fer-ho, són màgia negra
  - Mutabilitat
  - Facilitat de confondre l'asserció que un mètode s'hagi cridat amb la definició del resultat que ha de retornar en cas que s'invoqui
  - _Whiteboxness_: Si programem la prova per a que interactuï amb els components d'una manera determinada, no podem refactorizar per a que ho faci d'una altra
  - Lògica: Els _mock_ permeten (de fet, conviden a) programar escenaris impossibles, en que les respostes del component _mockejat_ no responen a cap lògica. e.g. Un component de bd que quan li demanes una entitat per id te la retorna però quan li demanes que et llisti entitats, no en retorna cap amb aquell id 
- [ ] Implementacions _production ready_ dels components a injectar
  - Com les fem _production ready_? Fent-les passar per la mateixa bateria de proves que les de producció
- [ ] Limitacions de les proves automatitzades basades en exemples
  - Limitacions dels exemples escollits pels programadors: Ús de dades aleatòries als exemples
    - És rellevant el valor concret de cada atribut de l'objecte d'exemple? O hi ha parts que tant s'hi val quin valor tinguin? Quina mantenibilitat tenen les proves si el lector ha de deduír per què el resultat esperat és aquell i no un altre?
    - Com triem exemples de proves? Quines dades acaben al nostre codi?
  - Limitacions de l'ús d'un únic exemple: property based testing
- [ ] _Property based testing_
  - Feedback en cas de fallida: La llavor per reproduir la prova i el númer d'iteració
  - Feedback en cas de fallida: _Shrinking_
  - Feedback sobre els valors generats: Classificacions
  - Fins quan provar? No et limitis a un nombre d'iteracions: fes proves fins que hagis provat tot el que volies provar
  - _Better shrinking_: Quan parem de fer shrinking? Quan ja haguem recorregut tot l'arbre o bé haguem invertit un temps límit a intentar-ho (e.g. 2 min)
  - Generadors de dades de prova monàdics
  - Generadors i _shrinking_
  - Veure https://jqwik.net/docs/current/user-guide.html
  - [ ] Integrated vs type-based shrinking: https://hypothesis.works/articles/integrated-shrinking/
- [ ] Limitacions dels tests _white box_: Què passa quan un _refactor_ fa canviar tots els tests de les funcions i petits components?
  - Contra el testing unitari clàssic
- [ ] Tipus de proves
  - Unitàries
  - D'integració
  - Extrem a extrem
  - _Broad stack_
  - ...
- [ ] He trobat un *bug*, què faig?
  - Reproduir-lo i després resoldre'l
- [ ] TDD?
- [ ] _Flaky tests_: _Don't live with broken windows_
- [ ] Proves automatitzades i Integració Contínua
  - Prova només allò que canvia
  - Desplega només allò que canvia
  - Modularitza de tal manera que els components que interactuen amb sistemes externs lents (com les bases de dades), vagin a parar a un mòdul que només canvia si ha de canviar aquell component. Així pots fer un munt de feina sense tornar a executar les proves d'integració lentes que fan servir aquest sistema extern.