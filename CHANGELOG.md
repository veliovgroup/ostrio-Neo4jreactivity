Changelog
=========

### [0.8.4](https://github.com/VeliovGroup/ostrio-Neo4jreactivity/releases/tag/v0.8.4)

* Fix issue [#48](https://github.com/VeliovGroup/ostrio-neo4jdriver/issues/48)
* Add logo

### [0.8.1](https://github.com/VeliovGroup/ostrio-Neo4jreactivity/releases/tag/v0.8.1)

* Trying to fix issue described [here](https://github.com/VeliovGroup/ostrio-neo4jdriver/issues/11)
* Remove colon from file names, to avoid Windows compilation issues
* Support for `audit-argument-checks` package

### [0.8.0](https://github.com/VeliovGroup/ostrio-Neo4jreactivity/releases/tag/v0.8.0)

* Fix issue #43
* Add __latency compensation__ when using data as mini-mongo (mini-neo4j) representation
* [BREAKING CHANGE] `Meteor.neo4j.publish()` and `Meteor.neo4j.subscribe()` now accepts 4 parameters only. Use `publish(name, func, [onSubscribe])` and `subscribe(name, [opts], link)` methods, which is available on object returned from `Meteor.neo4j.collection(name)`

### [0.7.3](https://github.com/VeliovGroup/ostrio-Neo4jreactivity/releases/tag/v0.7.3)

* Minor code refactoring

### [0.7.2](https://github.com/VeliovGroup/ostrio-Neo4jreactivity/releases/tag/v0.7.2)

* `mongo` package dependency suggested by @Neobii

### [0.7.1](https://github.com/VeliovGroup/ostrio-Neo4jreactivity/releases/tag/v0.7.1)

* Minor enhancements
* Solve issue with standard Neo4j Authorisation
* Neo4jDriver update to v0.2.12

### [0.7.0](https://github.com/VeliovGroup/ostrio-Neo4jreactivity/releases/tag/v0.7.0)

Added:
* Meteor.neo4j.collection - Create Mongo like neo4j collection
* Meteor.neo4j. publish - Publish Mongo like neo4j collection
* Meteor.neo4j. subscribe - Subscribe on Mongo like neo4j collection

Also:
* Code rewritten to coffee
* Better in-code docs
* Better documentation in readme.md

### [0.6.0](https://github.com/VeliovGroup/ostrio-Neo4jreactivity/releases/tag/v0.6.0)

* Overall improvements
* Fix issue with dotted keys in Mongo >= 2.6.0:
  - Now if you expect to retrieve key field.key, it will be available as field_key

### [0.5.3](https://github.com/VeliovGroup/ostrio-Neo4jreactivity/releases/tag/v0.5.3)

* Use Meteor.bindEnvironment instead of Fibers to require npm-package
* Remove unneeded packages

### [0.5.0](https://github.com/VeliovGroup/ostrio-Neo4jreactivity/releases/tag/v0.5.0)

* Fix issue with aggregation
* Unify get() method for reactive data on Server and Client
* Unify data returned via callback on Server and Client
* Almost fully rewritten code
* Library now initialized as solid object
* Fix issue with allow/deny rules
* Improved parseSensitivities method
* Updated docs
* Driver was well tested on different Cypher queries

### [0.4.3](https://github.com/VeliovGroup/ostrio-Neo4jreactivity/releases/tag/v0.4.3)

* Add neo4j.connectionURL property to change Neo4j URL on the fly
* Better docs

### [0.4.2](https://github.com/VeliovGroup/ostrio-Neo4jreactivity/releases/tag/v0.4.2)

* Add jshint globals and rules
* Code is refactored
* Better Sensitivities look up
* Better Cypher mapping
* Better caching (for write queries)
* UPD due to Meteor updates
* Add missed dependencies

### [0.3.6](https://github.com/VeliovGroup/ostrio-Neo4jreactivity/releases/tag/v0.3.6)

* Bug fix for mapping parameters in Cypher query, we've replaced it with our own function
