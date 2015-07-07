[![Join the chat at https://gitter.im/VeliovGroup/ostrio-neo4jdriver](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/VeliovGroup/ostrio-neo4jdriver?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

![Neo4j Reactivity Driver](https://raw.githubusercontent.com/VeliovGroup/ostrio-Neo4jreactivity/dev/logo-alt.png)

 - [About](#neo4j-db-reactive-layer-for-meteor)
 - [Example Application](#example-application)
 - [Installation](#install-the-driver)
 - [Notes](#several-notes)
   * [TTL](#ttl)
   * [Two ways to query Neo4j](#the-way-to-work-with-queries)
 - [API](#api)
   * [Isomorphic](#isomorphic)
   * [Server](#server)
   * [Client](#client)
   * [Supported Cypher Operators](#predefined-cypher-operators)
 - [More about reactive data](#about-reactive-data-and-queries)
 - [Usage examples](#usage-examples)
   * [As collection and publish/subscribe](#as-collection-and-publishsubscribe)
   * [As methods/call](#as-methodscall)
   * [Execute query on Client](#execute-query-on-client-side)
 - [Test on your Dev stage](#testing--dev-usage)
 - [Get deeper to understanding the package](#understanding-the-package)

Neo4j DB reactive layer for Meteor
=======
**Neo4jreactivity** creates reactive and isomorphic layer between Neo4j and your Meteor based application. All **write** requests is synchronized between all clients. Please see this package on [atmospherejs.com](https://atmospherejs.com/ostrio/neo4jreactivity).

Example Application
=======
The basic example is build on top of `--example leaderboard` - the [Meteor's Neo4j-based Leaderboard App](https://github.com/VeliovGroup/Meteor-Leaderboard-Neo4j) 


Install the driver
=======
```
meteor add ostrio:neo4jreactivity
```

Several Notes
=======
##### TTL
If you have many different queries to Neo4j database on production environment, you will probably want to avoid `Neo4jCache` collection overwhelming. Make build-in JavaScript-based TTL utility is useless, so we are suggest to take a look on [TTL indexes](http://docs.mongodb.org/manual/core/index-ttl/) and [expire data tutorial](http://docs.mongodb.org/manual/tutorial/expire-data/). `Neo4jCache` records has `created` {*Date*} field, so in our case it will be something like:
```javascript
/* run this at mongodb shell */
db.Neo4jCache.createIndex({ 
  created: 1 
},{ 
  expireAfterSeconds: 3600 * 24 /* 3600 * 24 = 1 day */
}); 
```

##### The way to work with queries
In documentation below you will find two different approaches how to send queries and retrieve data to/from Neo4j database. It is `methods`/`calls` and `collection`/`publish`/`subscription`.

It is __okay__ to combine them both. Most advanced way is to use `methods`/`calls`, - using this approach allows to you send and retrieve data directly to/from Neo4j database, our driver will only hold reactive updates on all clients. 

But at the same moment `collection`/`publish`/`subscription` approach has latency compensation and let to work with data and requests as with minimongo instance, but limited to simple `insert`/`update`/`remove` operations on data sets, so you can't set relations, indexes, predicates and other Cypher query options (__Labels and Properties__ is well supported. For Labels use `__labels` property as `{__labels: ":First:Second:Third"}`).


API
=======

## Isomorphic
 * `Meteor.neo4j.allowClientQuery`
  - `allowClientQuery` {*Boolean*} - Allow/Deny Cypher queries execution on the client side
 * `Meteor.neo4j.connectionURL = 'http://user:pass@localhost:7474';` 
  - Set connection URL, uncluding login and password to Neo4j DataBase
  - [Example](https://github.com/VeliovGroup/Meteor-Leaderboard-Neo4j/blob/a6b467f43ccf20f39189e10b5d521fe12b4a55a2/lib/neo4j.js#L4)
 * `Meteor.neo4j.rules.write` - Array of strings with Cypher write operators
 * `Meteor.neo4j.rules.read` - Array of strings with Cypher read operators
 * `Meteor.neo4j.set.allow([rules])` - Set allowed Cypher operators for client side
  - `rules` {*[String]*} - Array of Cyphper query operators Strings
 * `Meteor.neo4j.set.deny([rules])` - Set denied Cypher operators for client side
  - `rules` {*[String]*} - Array of Cyphper query operators Strings
  - For example to deny all write queries, use: `Meteor.neo4j.set.deny(Meteor.neo4j.rules.write)`
  - [Example](https://github.com/VeliovGroup/Meteor-Leaderboard-Neo4j/blob/a6b467f43ccf20f39189e10b5d521fe12b4a55a2/lib/neo4j.js#L6)
 * `Meteor.neo4j.query(query, opts, callback)` - __Returns__ reactive {Object} with `get()` method.
  - `query` {*String*} - Name of publish function. Please use same name in collection/publish/subscription
  - `opts` {*Object*} - A map of parameters for the Cypher query.
  - `callback` {*Function*} - Callback which runs after each subscription
    * `error` {*Object*|*null*} - Error of Neo4j Cypher query execution or null
    * `data` {*Object*|*null*} - Data or null from Neo4j Cypher query execution
  - [Example](https://github.com/VeliovGroup/Meteor-Leaderboard-Neo4j/blob/eabeaa853f634af59295680c5c7cf8dd9ac5437c/leaderboard.js#L9)
 * `Meteor.neo4j.collection(name)`
  - `name` {*String*} - Name of collection. 
  ```coffeescript
  users = Meteor.neo4j.collection 'Users'
  ```
  - This method returns collection with next methods:
    * `publish(name, func, [onSubscribe])` [**Server**] - Publish dataset to client. 
      - `name` {*String*} - Publish/Subscription name
      - `func` {*Function*} - Function which returns Cypher query
      - `onSubscibe` {*Function*} - Callback function called right after data is published
      - [Example](https://github.com/VeliovGroup/Meteor-Leaderboard-Neo4j/blob/a6b467f43ccf20f39189e10b5d521fe12b4a55a2/leaderboard.js#L85)
    ```coffeescript
    users.publish 'currentUser', () ->
      return 'MATCH (user:User {_id: {_id}}) RETURN user;'
    ```
    * `subscribe(name, [opts], link)` [**Client**] - Subscribe on dataset.
      - `name` {*String*} - Publish/Subscription name
      - `opts` {*Object*|*null*} - A map of parameters for the Cypher query
      - `link` {*String*} - Sub object name, to link as MobgoDB row(s). See example below:
      - [Example](https://github.com/VeliovGroup/Meteor-Leaderboard-Neo4j/blob/a6b467f43ccf20f39189e10b5d521fe12b4a55a2/leaderboard.js#L15)
    ```coffeescript
    users.subscribe 'currentUser', _id: Meteor.userId(), 'user'
    ```
    * `find([selector], [options])` - [Example](https://github.com/VeliovGroup/Meteor-Leaderboard-Neo4j/blob/a6b467f43ccf20f39189e10b5d521fe12b4a55a2/leaderboard.js#L20). Use to search thru returned data from Neo4j
      - `fetch()` - Use to fetch Cursor data
    * `findOne([selector], [options])`
    * `insert(doc, [callback])` - [Example](https://github.com/VeliovGroup/Meteor-Leaderboard-Neo4j/blob/a6b467f43ccf20f39189e10b5d521fe12b4a55a2/leaderboard.js#L52)
    * `update(selector, modifier, [options], [callback])` - [Example](https://github.com/VeliovGroup/Meteor-Leaderboard-Neo4j/blob/a6b467f43ccf20f39189e10b5d521fe12b4a55a2/leaderboard.js#L39)
    * `upsert(selector, modifier, [options], [callback])`
    * `remove(selector, [callback])` - [Example](https://github.com/VeliovGroup/Meteor-Leaderboard-Neo4j/blob/a6b467f43ccf20f39189e10b5d521fe12b4a55a2/leaderboard.js#L76)
    * __Note__: All `selector`s and `doc` support `__labels` property, - use it to set Cypher label on insert or searching data, see [this example](https://github.com/VeliovGroup/Meteor-Leaderboard-Neo4j/blob/a6b467f43ccf20f39189e10b5d521fe12b4a55a2/leaderboard.js#L55)
    * [Collection() example](https://github.com/VeliovGroup/Meteor-Leaderboard-Neo4j/blob/master/leaderboard.js#L10)

## Server
 * `Meteor.neo4j.methods(object)` - Create server Cypher queries
  - `object` {*Object*} - Object of method functions, which returns Cypher query string
  - [Example](https://github.com/VeliovGroup/Meteor-Leaderboard-Neo4j/blob/eabeaa853f634af59295680c5c7cf8dd9ac5437c/leaderboard.js#L98)
 * `Meteor.neo4j.publish(collectionName, name, func, [onSubscribe])`
  - `collectionName` {*String*} - Collection name of method function
  - `name` {*String*} - Name of publish function. Please use same name in publish/subscription
  - `func` {*Function*} - Function wich returns Cypher query string
  - `onSubscribe` {*Function*} - Callback which runs after each subscription
  - [Example](https://github.com/VeliovGroup/Meteor-Leaderboard-Neo4j/blob/16c710c2ffac58691beb295a0c5f06c143cc9945/leaderboard.js#L76)

## Client
 * `Meteor.neo4j.call(name, [[opts], [link].. ], callback)` - Call server Neo4j method
Call for method registered via `Meteor.neo4j.methods`.
  - `name` {*String*} - Name of method function
  - `opts` {*Object*} - A map of parameters for the Cypher query.
  - `callback` {*Function*} - Returns `error` and `data` arguments.
  - Returns {*Object*} - With `cursor` and reactive `get()` method
  - [Example](https://github.com/VeliovGroup/Meteor-Leaderboard-Neo4j/blob/eabeaa853f634af59295680c5c7cf8dd9ac5437c/leaderboard.js#L39)
 * `Meteor.neo4j.subscribe(collectionName, name, [opts], [link])`
  - `collectionName` {*String*} - Collection name of method function
  - `name` {*String*} - Name of subscribe function. Please use same name in publish/subscription
  - `opts` {*Object*} - A map of parameters for the Cypher query.
  - `link` {*String*} - Sub object name, to link as MobgoDB row(s)
  - [Example](https://github.com/VeliovGroup/Meteor-Leaderboard-Neo4j/blob/16c710c2ffac58691beb295a0c5f06c143cc9945/leaderboard.js#L15)
  - __Note__: Wrap `Meteor.neo4j.subscribe()` into `Tracker.autorun()`

----------
### Predefined Cypher Operators:
 - __Allow__:
  * `RETURN`
  * `MATCH`
  * `SKIP`
  * `LIMIT`
  * `OPTIONAL`
  * `ORDER BY`
  * `WITH`
  * `AS`
  * `WHERE`
  * `CONSTRAINT`
  * `UNWIND`
  * `DISTINCT`
  * `CASE`
  * `WHEN`
  * `THEN`
  * `ELSE`
  * `END`
  * `CREATE`
  * `UNIQUE`
  * `MERGE`
  * `SET`
  * `DELETE`
  * `REMOVE`
  * `FOREACH`
  * `ON`
  * `INDEX`
  * `USING`
  * `DROP`

 - __Deny__: None

 - __Write__:
  * `CREATE`
  * `SET`
  * `DELETE`
  * `REMOVE`
  * `INDEX`
  * `DROP`
  * `MERGE`

----------

About reactive data and queries
==========
__Note__: This is very important to use same node's link names for same node types in all Cypher queries, cause the way Neo4jReactivity subscribes on data. For example if we would like to retrieve Users from Neo4j and update them later, so data will be updated reactively:
```sql
MATCH (usr {type: 'User'}) RETURN usr

# To update use only `usr` alias for node: 
MATCH (usr {type: 'User', perms: 'guest'}) SET usr.something = 2
```

Of course __Neo4jReactivity__ knows about Neo4j labels and use them for subscription too. With labels you may use different node's name aliases, __but it's not recommended__:
```sql
# To retrieve
MATCH (a:User) RETURN a

# To update: 
MATCH (b:User {perms: 'guest'}) SET b.something = 2
```

It will work, but much better if you will use: 
```sql
# To retrieve
MATCH (user:User) RETURN user

# To update: 
MATCH (user:User {perms: 'guest'}) SET user.something = 2
```

Usage examples:
==========
#### As collection and publish/subscribe
###### Create collection [*Isomorphic*]
```coffeescript
friends = Meteor.neo4j.collection 'friends'
```

###### Publish data [*Server*]
```coffeescript
friends.publish 'allFriends', () ->
  return "MATCH (user {_id: {userId}})-[:FriendOf]->(friends) RETURN friends"
```

###### Subscribe on this data [*Client*]
```coffeescript
friends.subscribe 'allFriends', {userId: Meteor.userId()}, 'friends'
```

###### Template helper [*Client*]
```coffeescript
Template.friendsNamesList.helpers
  friends: ()->
    friends.find({})
```

###### In Template:
```html
<template name="friendsNamesList">
    <ul>
        {{#each friends}}
           <li>{{name}}</li>
        {{/each}}
    </ul>
</template>
```
#### As methods/call
###### In Server Methods
```coffeescript
#CoffeeScript
Meteor.neo4j.methods 
    getUsersFriends: () ->
        return  "MATCH (user {_id: {userId}})-[:FriendOf]->(friends) RETURN friends"
```

###### In Helper
```coffeescript
#CoffeeScript
Template.friendsNamesList.helpers
    userFriends: () ->
        Meteor.neo4j.call 'getUsersFriends', {userId: Meteor.userId()}, (error, data) ->
            throw new Meteor.error '500', 'Something goes wrong here', error.toString() if error
            else
              Session.set 'currenUserFriends', data
        return Session.get 'currentUserFriens'
```

###### In Template:
```html
<template name="friendsNamesList">
    <ul>
        {{#each userFriends.friends}}
           <li>{{name}}</li>
        {{/each}}
    </ul>
</template>
```

###### About security
By default query execution is allowed only on server, but for development purpose (or any other), you may enable it on client:
```coffeescript
#Write this line in /lib/ directory to execute this code on both client and server side
Meteor.neo4j.allowClientQuery = true
#Do not forget about minimum security, deny all write queries
Meteor.neo4j.set.deny Meteor.neo4j.rules.write
```

To allow or deny actions use ```neo4j.set.allow(['array of strings'])``` and ```neo4j.set.deny(['array of strings'])```
```coffeescript
#CoffeeScript
Meteor.neo4j.set.allow ['create', 'Remove']
Meteor.neo4j.set.deny ['SKIP', 'LIMIT']

#OR to allow or deny all
Meteor.neo4j.set.allow '*'
Meteor.neo4j.set.deny '*'

#To deny all write operators
Meteor.neo4j.set.deny Meteor.neo4j.rules.write

#default rules
Meteor.neo4j.rules = 
    allow: ['RETURN', 'MATCH', 'SKIP', 'LIMIT', 'OPTIONAL', 'ORDER BY', 'WITH', 'AS', 'WHERE', 'CONSTRAINT', 'UNWIND', 'DISTINCT', 'CASE', 'WHEN', 'THEN', 'ELSE', 'END', 'CREATE', 'UNIQUE', 'MERGE', 'SET', 'DELETE', 'REMOVE', 'FOREACH', 'ON', 'INDEX', 'USING', 'DROP']
    deny: []
```

##### Execute query on client side:
```coffeescript
#Write this line in /lib/ directory to execute this code on both client and server side
Meteor.neo4j.allowClientQuery = true

#Client code
getAllUsers = ->
    return Meteor.neo4j.query('MATCH (a:User) RETURN a').get();
```

**For more info see: [neo4jdriver](https://github.com/VeliovGroup/ostrio-neo4jdriver) and [node-neo4j](https://github.com/thingdom/node-neo4j)**

Code licensed under Apache v. 2.0: [node-neo4j License](https://github.com/thingdom/node-neo4j/blob/master/LICENSE) 

Testing & Dev usage
===========
###### Local usage

 - Download (or clone) to local dir
 - **Stop meteor if running**
 - Run ```mrt link-package [*full path to folder with package*]``` in a project dir
 - Then run ```meteor add ostrio:neo4jreactivity```
 - Run ```meteor``` in a project dir
 - From now any changes in ostrio:neo4jreactivity package folder will cause rebuilding of project app



Understanding the package
===========
After installing `ostrio:neo4jreactivity` package - you will have next variables:
 - `Meteor.Neo4j;` - [*Server*] GraphDatabase object from node-neo4j npm package. Use to connect to other Neo4j servers.
 - `Meteor.N4JDB;` - [*Server*] GraphDatabase instance connected to Neo4j server. Use to run Cypher queries directly in Neo4j DB, without any reactivity
 - `Meteor.neo4j;` - [*Isomorphic*] Neo4jReactivity Driver object

###### Meteor.Neo4j;
```javascript
/* 
 * Server only
 * @class
 * @name Neo4j
 * @param url {string} - URL to Neo4j database
 * Note: It’s better to store URL in environment 
 * variable, 'NEO4J_URL' or 'GRAPHENEDB_URL' - 
 * so it will be automatically picked up by our driver
 * 
 * @description Run it to create connection to database
 */
Meteor.N4JDB = new Meteor.Neo4j(/* URL TO SERVER */);
```

Newly created object has next functions, you will use:
```javascript
/* @name query */
Meteor.N4JDB.query('MATCH (n:User) RETURN n', null /* A map of parameters for the Cypher query */, function(err, data){
    Session.set('allUsers', data);
});

/* @name listen */
Meteor.N4JDB.listen(function(query, opts){
    console.log('Incoming request to neo4j database detected!');
});
```

###### Meteor.neo4j;
```javascript
/* Both (Client and Server)
 * @object
 * @name neo4j
 * @description Application wide object neo4j
 */
Meteor.neo4j;
Meteor.neo4j.allowClientQuery = true; /* Allow/deny client query executions */
Meteor.neo4j.connectionURL = null; /* Set custom connection URL to Neo4j DB, Note: It’s better to store URL in environment variable, 'NEO4J_URL' or 'GRAPHENEDB_URL' - so it will be automatically picked up by the driver */
```

`neo4j` object has multiple functions, you will use:
```javascript
/* @namespace Meteor.neo4j.set
 * @name allow
 * @param rules {array} - Array of Cypher operators to be allowed in app
 */
Meteor.neo4j.set.allow(rules /* array of strings */);

/* @namespace Meteor.neo4j.set
 * @name deny
 * @param rules {array} - Array of Cypher operators to be forbidden in app
 */
Meteor.neo4j.set.deny(rules /* array of strings */);


/*
 * @function
 * @namespace neo4j
 * @name query
 * @param query {string}      - Cypher query
 * @param opts {object}       - A map of parameters for the Cypher query
 * @param callback {function} - Callback function(error, data){...}. Where is data is [REACTIVE DATA SOURCE]
 *                              So to get data for query like:
 *                              'MATCH (a:User) RETURN a', you will need to: 
 *                              data.a
 * @param settings {object}   - {returnCursor: boolean} if set to true, returns Mongo\Cursor 
 * @description Isomorphic Cypher query call
 * @returns Mongo\Cursor or ReactiveVar [REACTIVE DATA SOURCE] 
 *
 * @note Please keep in mind what on client it returns ReactiveVar, but on server it returns just data, see difference in usage at example below
 *
 */
allUsers = Meteor.neo4j.query('MATCH (users:User) RETURN users');
var users = allUsers.get().users;

/* or via callback, on callback there is no need to run `get()` method */
var users;
Meteor.neo4j.query('MATCH (users:User) RETURN users', null, function(error, data){
    users = data.users;
});


/*
 * Server only
 * @name methods
 * @param methods {object} - Object of methods, like: { methodName: function(){ return 'MATCH (a:User {name: {userName}}) RETURN a' } }
 * @description Create server methods to send query to neo4j database
 */
Meteor.neo4j.methods({
   'GetAllUsers': function(){
      return 'MATCH (users:User) RETURN users';
   }
});


/*
 * Client only
 * @name call
 * @description Call for server method registered via neo4j.methods() method, 
 *              returns error, data via callback.
 */
Meteor.neo4j.call('GetAllUsers', null, function(error, data){
   Session.set('AllUsers', data.users);
});
```

###### Meteor.N4JDB;
```javascript
/* 
 * Server only
 * @description Current GraphDatabase connection object, basically created from 'new Neo4j()''
 */
Meteor.N4JDB;


/* You may run queries with no returns on server with it: */
Meteor.N4JDB.query('CREATE (a:User {_id: ”123”})');


/* To set listener: */
Meteor.N4JDB.listen(function(query, opts){
  console.log('Incoming query: ' + query, opts);
});
```
