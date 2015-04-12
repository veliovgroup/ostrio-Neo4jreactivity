## Neo4j DB reactive layer for Meteor
**Neo4j reactivity** creates reactive and isomorphic layer between Neo4j and your Meteor based application. All *write* requests is synchronized between all clients. Please see this package on [atmospherejs.com](https://atmospherejs.com/ostrio/neo4jreactivity).

##### Example App
The basic example is build on top of `--example leaderboard` - the [Meteor Leaderboard Neo4j Example App](https://github.com/VeliovGroup/Meteor-Leaderboard-Neo4j) 


##### Install the driver
```
meteor add ostrio:neo4jreactivity
```

##### Known issues:
 - __[Error: Neo4jCacheCollection.upsert in v2.2.*](https://github.com/VeliovGroup/ostrio-Neo4jreactivity/issues/22)__: - You need to disable default authentication in Neo4j-2.2.*:
    * Open file `/Your_Neo4j-2.2.0_install_path/conf/neo4j-server.properties`
    * Change line: `dbms.security.auth_enabled=true` (to false)


### API
__Note__: This is very important to use same names for same node types in all Cypher queries, cause the way Neo4jReactivity subscribes on data. For example if we would like to retrieve Users from Neo4j and update them later: 
  * `MATCH (usr {type: 'User'}) RETURN usr`

to update use only `usr` alias for node: 
  * `MATCH (usr {type: 'User', perms: 'guest'}) SET usr.something = 2`

so data will be updated reactively.

Of course Neo4jReactivity knows about Neo4j labels and use them for subscription too. With labels you may use different node's name aliases, __but it's not recommended__, to retrieve: 
  * `MATCH (a:User) RETURN a`

to update: 
  * `MATCH (b:User {perms: 'guest'}) SET b.something = 2`

- it will work but much better if you will use to retrieve: 
  * `MATCH (user:User) RETURN a`

and to update: 
  * `MATCH (user:User {perms: 'guest'}) SET user.something = 2`

#### Isomorphic
##### Meteor.neo4j.allowClientQuery
 * `allowClientQuery` {Boolean} - Allow/Deny Cypher queries execution on the client side
```javascript
Meteor.neo4j.allowClientQuery = true;
```
##### Meteor.neo4j.connectionURL = 'http://...';
Set connection URL to Neo4j DataBase
##### Meteor.neo4j.rules.write - Array of strings with Cypher write operators
##### Meteor.neo4j.rules.read - Array of strings with Cypher read operators
##### Meteor.neo4j.set.allow([rules]) - Set allowed Cypher operators for client side
 * `rules` {[String]} - Array of Cyphper query operators Strings

---

##### Meteor.neo4j.set.deny([rules]) - Set denied Cypher operators for client side
 * `rules` {[String]} - Array of Cyphper query operators Strings
```javascript
/* Deny all write operations */
Meteor.neo4j.set.deny(Meteor.neo4j.rules.write);
```

---

##### Meteor.neo4j.query(query, opts, callback)
__Returns__ - reactive {Object} with `get()` method.
 * `query` {String} - Name of publish function. Please use same name in collection/publish/subscription
 * `opts` {Object} - A map of parameters for the Cypher query.
 * `callback` {Function} - Callback which runs after each subscription
    * error {Object|null} - Error of Neo4j Cypher query execution or null
    * data {Object|null} - Data or null from Neo4j Cypher query execution

###### [Example](https://github.com/VeliovGroup/Meteor-Leaderboard-Neo4j/blob/eabeaa853f634af59295680c5c7cf8dd9ac5437c/leaderboard.js#L9):
```javascript
var Players = Meteor.neo4j.query('MATCH (p:Player) RETURN p, count(p), p.score ORDER BY p.score DESC');

var Player;
Meteor.neo4j.query('MATCH (p:Player {id: {_id}}) RETURN p', {_id: Meteor.userId()}, function(err, data){
  if(err){
    throw new Meteor.Error(err);
  }
  Player = data.get().p;
});
```

---

##### Meteor.neo4j.collection(name)
 * `name` {String} - Name of collection. Please use same name in collection/publish/subscription
Create MongoDB-like collection, **only** supported methods:
 * `find({})` - [Example](https://github.com/VeliovGroup/Meteor-Leaderboard-Neo4j/blob/master/leaderboard.js#L23). Use to search thru returned data from Neo4j
    - `fetch()` - Use to fetch Cursor data

##### [Example](https://github.com/VeliovGroup/Meteor-Leaderboard-Neo4j/blob/master/leaderboard.js#L10)
```javascript
var Players = Meteor.neo4j.collection('players');
```

---

#### Server
##### Meteor.neo4j.methods(object)
 * `object` {Object} - Object of method functions, which returns Cypher query string

###### [Example](https://github.com/VeliovGroup/Meteor-Leaderboard-Neo4j/blob/eabeaa853f634af59295680c5c7cf8dd9ac5437c/leaderboard.js#L98):
```javascript
Meteor.neo4j.methods({
  'addPlayer': function(){
    return 'CREATE (a:Player {_id:"' + String.generate() + '", name: {userName}, score: 0})';
  },
  'removePlayer': function(){
    return 'MATCH (a:Player {_id:{playerId}}) DELETE a';
  }
});
```

---

##### Meteor.neo4j.publish(name, func, [onSubscribe])
 * `name` {String} - Name of publish function. Please use same name in collection/publish/subscription
 * `func` {Function} - Function wich returns Cypher query string
 * `onSubscribe` {Function} - Callback which runs after each subscription

###### Example:
```javascript
/* Create isomorphic collection */
var Players = Meteor.neo4j.collection('players');

if (Meteor.isClient) {
  Meteor.neo4j.publish('players', function(){
    return 'MATCH (a:Player) RETURN a ORDER BY a.score DESC';
  }, function(){
    /* onSubscribe callback */
    if (Players.findOne({})) {
      /*....*/
    }
  });
}
```

---
#### Client
##### Meteor.neo4j.call(name, [[opts], [link].. ], callback)
Call for method registered via `Meteor.neo4j.methods`.
 * `name` {String} - Name of method function
 * `opts` {Object} - A map of parameters for the Cypher query.
 * `callback` {function} - Returns `error` and `data` arguments. Data has `get()` method to get reactive data

###### [Example](https://github.com/VeliovGroup/Meteor-Leaderboard-Neo4j/blob/eabeaa853f634af59295680c5c7cf8dd9ac5437c/leaderboard.js#L30):
```javascript
/* Create isomorphic collection */
Meteor.neo4j.call('removePlayer', {playerId: Session.get('selectedPlayer')});
```

---

##### Meteor.neo4j.subscribe(name, [opts], [link])
 * `name` {String} - Name of subscribe function. Please use same name in collection/publish/subscription
 * `opts` {Object} - A map of parameters for the Cypher query.
 * `link` {String} - Sub object name, to link as MobgoDB row(s)

###### [Example](https://github.com/VeliovGroup/Meteor-Leaderboard-Neo4j/blob/master/leaderboard.js#L15):
```javascript
/* Create isomorphic collection */
var Players = Meteor.neo4j.collection('players');

Tracker.autorun(function(){
  /* For query like:'MATCH (a:Player) RETURN a ORDER BY a.score DESC', we link 'a' */
  Meteor.neo4j.subscribe('players', null, 'a');
});
```

----------
### Predefined Cypher Operators:
__Allow__:
  * 'RETURN'
  * 'MATCH'
  * 'SKIP'
  * 'LIMIT'
  * 'OPTIONAL'
  * 'ORDER BY'
  * 'WITH'
  * 'AS'
  * 'WHERE'
  * 'CONSTRAINT'
  * 'UNWIND'
  * 'DISTINCT'
  * 'CASE'
  * 'WHEN'
  * 'THEN'
  * 'ELSE'
  * 'END'
  * 'CREATE'
  * 'UNIQUE'
  * 'MERGE'
  * 'SET'
  * 'DELETE'
  * 'REMOVE'
  * 'FOREACH'
  * 'ON'
  * 'INDEX'
  * 'USING'
  * 'DROP'

__Deny__: None

__Write__:
  * 'CREATE'
  * 'SET'
  * 'DELETE'
  * 'REMOVE'
  * 'INDEX'
  * 'DROP'
  * 'MERGE'

----------

##### Usage examples:
###### In Server Methods
```coffeescript
#CoffeeScript
Meteor.neo4j.methods 
    getUsersFriends: () ->
        return  'MATCH (a:User {_id: {userId}})-[relation:friends]->(b:User) ' +
                'OPTIONAL MATCH (b:User)-[subrelation:friends]->() ' +
                'RETURN relation, subrelation, b._id AS b_id, b'
```

###### In Helper
```coffeescript
#CoffeeScript
Template.friendsNamesList.helpers
    userFriends: () ->

        Meteor.neo4j.call 'getUsersFriends', {userId: '12345'}, (error, data) ->
            if error
                 #handle error here
                 throw new Meteor.error '500', 'Something goes wrong here', error.toString()
            else
                Session.set 'currenUserFriends', data

        return Session.get 'currentUserFriens'
```

###### In Template:
```html
<template name="friendsNamesList">
    <ul>
        {{#each userFriends.b}}
           <li>{{b.name}}</li>
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
getAllUsers = () ->
    return Session.get('allUsers', Meteor.neo4j.query('MATCH (a:User) RETURN a'));
```

**For more info see: [neo4jdriver](https://github.com/VeliovGroup/ostrio-neo4jdriver) and [node-neo4j](https://github.com/thingdom/node-neo4j)**

Code licensed under Apache v. 2.0: [node-neo4j License](https://github.com/thingdom/node-neo4j/blob/master/LICENSE) 

-----
##### Testing & Dev usage
###### Local usage

 - Download (or clone) to local dir
 - **Stop meteor if running**
 - Run ```mrt link-package [*full path to folder with package*]``` in a project dir
 - Then run ```meteor add ostrio:neo4jreactivity```
 - Run ```meteor``` in a project dir
 - From now any changes in ostrio:neo4jreactivity package folder will cause rebuilding of project app

-----

##### Understanding the package
After installing `ostrio:neo4jreactivity` package - you will have next variables:
 - `Meteor.Neo4j;`
 - `Meteor.N4JDB;`
 - `Meteor.neo4j;`

###### var Neo4j;
```javascript
/* 
 * Server only
 * @class
 * @name Neo4j
 * @param url {string} - url to Neo4j database
 * Note: It’s better to store url in environment 
 * variable, 'NEO4J_URL' or 'GRAPHENEDB_URL' - 
 * so it will be automatically picked up by our driver
 * 
 * @description Run it to create connection to database
 */
var N4JDB = new Neo4j();
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

###### var neo4j;
```javascript
/* Both (Client and Server)
 * @object
 * @name neo4j
 * @description Application wide object neo4j
 */
Meteor.neo4j;
Meteor.neo4j.allowClientQuery = true; /* Allow/deny client query executions */
Meteor.neo4j.connectionURL = null; /* Set custom connection URL to Neo4j DB, Note: It’s better to store url in environment variable, 'NEO4J_URL' or 'GRAPHENEDB_URL' - so it will be automatically picked up by the driver */
```

`neo4j` object has multiple functions, you will use:
```javascript
/* @namespace neo4j.set
 * @name allow
 * @param rules {array} - Array of Cypher operators to be allowed in app
 */
Meteor.neo4j.set.allow(rules /* array of strings */);

/* @namespace neo4j.set
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

###### var N4JDB;
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
