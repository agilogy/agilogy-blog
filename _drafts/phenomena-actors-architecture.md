---
layout: post
title: Phenomena / Actors Architecture
---

## Elevator pitch

Design and test your application as part of a system owned by you that includes software and infrastructure. Design the system to observe and react to phenomena (usually requests, commands and events) and send signals and / or requests to external actors.

## Your service as a whole

The P/A Architecture centers around the service, a software system that acts as a web app or as a software as a service, that belongs to you (as a team). The service is composed of the software but also the infrastructure on top of which runs, including servers, databases, file systems...

The service observes and reacts to [phenomena](https://www.dictionary.com/browse/phenomenon), facts, occurrences or circumstances outside it. Typically there are 2 types of phenomenon: requests to the system (e.g. via an HTTP API) and events to which the system reacts (e.g. an event in a message queue); one particular event is the passing of time (e.g. when a reaction is triggered according to a schedule).

The system also interacts with actors external to it, like users (via their UIs) or third party services. When those actors trigger or initiate the communication, they can simply be seen as phenomena to which the system reacts. But when the interaction is triggered by the system, the actors are driven actors.

## Phenomena: Requests, commands and events

Typically our system reacts to the outside by fulfilling **requests** in a synchronous request / response protocol. We will consider that requests demand synchronous responses from the system. That's the case of most APIs out there, no matter the exact protocol they speak.

But our system may also react to **commands** sent to it. They ask the system to perform some task in a fire and forget way. The system should fulfillthe command, but no synchronous response is expected by the sender of the command, althought the system may send some signal back to the actor.

Finally, our system may react to **events**. In that case, no external actor is demanding anything from the system, but it is the system that decides to reacto somehow to some event it detected.

No matter its kind, everry phenomenon is of one particular type (e.g. a particular request, like "get the user by id") and has some additional data (e.g. id = 34).

It is important to note that requests, commands and events all have an origin outside of our system. Although the infrastructure belonging to the system may trigger some behavior, even taking in consideration that the implementation of such reaction will be implemented almost identicall, it will not be considered a phenomenon.

## The Domain

At the heart of the system there is the domain[^1]. The domain is a high level representation of the business and it's technology agnostic.

[^1]: That's what the Hexagonal Architecture calls the Hexagon.

In the domain, we will model the requests, commands and events as functions that receive the phenomenon type and data and produce the response data (if any) and possybly some side effect (e.g. the insertion of a row in a database). All of the input and output data there might be is modeled, in the domain, using a domain data model [^2].

[^2]: Not to be confused with a Domain Model

These functions may be grouped in modules as needed. In typical OO systems, these modules may be modelled by interfaces or classes with the functions being methods defined in those interfaces or classes. We are calling these functions request functions, command functions and event functions or, globally, **phenomenon functions**. The implementation of these phenomenon functions will implement the actual business logic of our system. 
TODO: Call them apis? Stop talking about functions and talk about interfaces?

Whenever one of such functions needs to interact with the system infrastructure (e.g. query a database), we will use the [Configurable Dependency Pattern](https://en.wikipedia.org/wiki/Dependency_inversion_principle) (aka Dependency Inversion Principle). That is, we will define a domain function (or group of functions, typically in an interface acting as a module) that will be implemented by some component outside the domain.
TODO: Call them repositories? Stop talking about functions and talk about interfaces?

Finally, when one of the phenomenon functions need to trigger the communication with an actor (e.g. make a request to an external API), we will apply the Configurable Dependency Pattern again. 
TODO: Call them actors or services? Stop talking about functions and talk about interfaces?

Although, from the point of view of the domain, both repositories and services are outside the domain and are represented by configurable dependencies, the distinction is important in terms of ownership and that will affect, at least, at how we test them.

## API adapters

TODO: Like driver adapters

## Repository and service implementations

TODO: Like driven adapters

## Motivation

Thi is my humble response to [Ports and Adapters Architecture](https://alistair.cockburn.us/hexagonal-architecture/) (aka Hexagonal Architecture) originally described [here](http://wiki.c2.com/?HexagonalArchitecture) by [Alistair Cockburn](https://twitter.com/totheralistair).

Ports and Adapters proposed a clean solution to a flawled [layerered architecture](https://en.wikipedia.org/wiki/Multitier_architecture). The problem was that the original layers (presentation / application / business / data access) seemed to imply some sorting from higher to lower level of abstraction, like layers do in [typical layered network protocols](https://en.wikipedia.org/wiki/Internet_protocol_suite). Cockburn observed that, in fact, the higher level of abstraction corresponds to the application and domain layers, while both presentation and data access layers where lower level, closer to the actual infrastructure.

I do think the proposed solution is elegant and solves the mentioned problem. But I also think many developers are confused by its use of the number 6, its ["asymmetrical symmetry"](https://jmgarridopaz.github.io/content/hexagonalarchitecture.html#tc4) and, maybe, because it is not easy to find a nice introductory description of it, like [this one](https://jmgarridopaz.github.io/content/hexagonalarchitecture.html) by [Juan Manuel Garrido de Paz](https://twitter.com/JuanMGarridoPaz)[^3].

[^3]: Most of the documentation I had found before this excellent summary was in the form of dissertation and I felt it was needed to read several documents chronologically to understand the final proposal of the architecture. One of the most confusing aspects, in my opinion, was, initially, the aforementioned asymmetrical symmetry, where some adapters are drivers or primary actors while others are driven or secondary actors. None of this was clear to me in the first documents describing the architecture.

More important than that, I feel that with the raise of DevOps, more and more teams are taking ownership of complete systems, including software and the infrastructure it operates on. From that point of view, suddenly, I find the aforementioned symmetry less appealing: while all of my database, the user interface and a mobile push notification network are OUTSIDE of my software, the first of them belongs to my team and deserves some special attention and a particular testing strategy of its own.






