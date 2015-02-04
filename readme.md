## Neo4j DB reactive layer for Meteor
**Neo4j reactivity** creates mongodb layer between neo4j and your Meteor based application. All *write* requests is synchronized between all clients. Please see this package on [atmospherejs.com](https://atmospherejs.com/ostrio/neo4jreactivity) .

##### Example App
The basic example is build on top of `--example leaderboard` - the [Meteor Leaderboard Neo4j Example App](https://github.com/VeliovGroup/Meteor-Leaderboard-Neo4j) 

##### Description
Due to security lack we decide separate server side with queries, and client side with handlers via methods.

To create method use ```Meteor.neo4j.methods({'object of functions'})``` with functions which returns query string (see example below).

To call and handle database answer use: ```Meteor.neo4j.call('methodName', {'A map of parameters for the Cypher query'}, function(error, data){...})```

##### Install the driver
```
meteor add ostrio:neo4jreactivity
```

##### Usage example:
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
