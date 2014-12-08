**Neo4j reactivity** creates mongodb layer between neo4j and your meteor based application.

All requests is synchronized between all clients, as in real reactivity.

```neo4j.call``` method returns reactive data source - ```ReactveVar```, so data from Neo4j database is available from ```.get()``` method, if query has no data it is equals to ```null```

On [atmospherejs.com](https://atmospherejs.com/ostrio/neo4jreactivity)

### Description
Due to security lack we decide separate server side with queries, and client side with handlers via methods.

To create method use ```neo4j.methods({'object of functions'})``` with functions which returns query string (see example below).

To call and handle database answer use ```neo4j.call('methodName', {'A map of parameters for the Cypher query'}, function(error, data){...})```, to get reactive data call ```get()``` method on data returned from Neo4j database, like: ```data.get()```

### Install to meteor
```
meteor add ostrio:neo4jreactivity
```

### Usage example:
```coffeescript
#CoffeeScript
#In Server Methods
neo4j.methods 
    getUsersFriends: () ->
        return  'MATCH (a:User {_id: {userId}})-[relation:friends]->(b:User) ' +
                'OPTIONAL MATCH (b:User)-[subrelation:friends]->() ' +
                'RETURN relation, subrelation, b._id AS b_id, b'

#In Helper
Template.friendsNamesList.helpers
    userFriends: () ->

        neo4j.call 'getUsersFriends', {userId: '12345'}, (error, record) ->
            if error
                 #handle error here
                 throw new Meteor.error '500', 'Something goes wrong here', error.toString()
            else
                Session.set 'currenUserFriends', record.get()

        return Session.get 'currentUserFriens'
```

### In Template:
```html
<template name="friendsNamesList">
    <ul>
        {{#each userFriends.b}}
           <li>{{b.name}}</li>
        {{/each}}
    </ul>
</template>
```

### About security
By default query execution is allowed only on server, but for development purpose (or any other), you may enable it on client:
```coffeescript
#Write this line in /lib/ directory to execute this code on both client and server side
neo4j.allowClientQuery = true
#Do not forget about minimum security, deny all write queries
neo4j.set.deny neo4j.rules.write
```

To allow or deny actions use ```neo4j.set.allow(['array of strings'])``` and ```neo4j.set.deny(['array of strings'])```
```coffeescript
#CoffeeScript
neo4j.set.allow ['create', 'Remove']
neo4j.set.deny ['SKIP', 'LIMIT']

#OR to allow or deny all
neo4j.set.allow '*'
neo4j.set.deny '*'

#To deny all write operators
neo4j.set.deny neo4j.rules.write

# default rules
neo4j.rules = 
    allow: ['RETURN', 'MATCH', 'SKIP', 'LIMIT', 'OPTIONAL', 'ORDER BY', 'WITH', 'AS', 'WHERE', 'CONSTRAINT', 'UNWIND', 'DISTINCT', 'CASE', 'WHEN', 'THEN', 'ELSE', 'END', 'CREATE', 'UNIQUE', 'MERGE', 'SET', 'DELETE', 'REMOVE', 'FOREACH', 'ON', 'INDEX', 'USING', 'DROP']
    deny: []
```

### Execute query on client side:
```coffeescript
#Write this line in /lib/ directory to execute this code on both client and server side
neo4j.allowClientQuery = true

#Client code
getAllUsers = () ->
    neo4j.query('MATCH (a:User) RETURN a', null, function(err, data){
       Session.set('allUsers', data.get());
    });

    return Session.get('allUsers');
```

**For more info see: [neo4jdriver](https://github.com/VeliovGroup/ostrio-neo4jdriver) and [node-neo4j](https://github.com/thingdom/node-neo4j)**

Code licensed under Apache v. 2.0: [node-neo4j License](https://github.com/thingdom/node-neo4j/blob/master/LICENSE) 

-----
#### Testing & Dev usage
##### Local usage

 - Download (or clone) to local dir
 - **Stop meteor if running**
 - Run ```mrt link-package [*full path to folder with package*]``` in a project dir
 - Then run ```meteor add ostrio:neo4jreactivity```
 - Run ```meteor``` in a project dir
 - From now any changes in ostrio:neo4jreactivity package folder will cause rebuilding of project app
