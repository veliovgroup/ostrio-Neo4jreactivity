**Neo4j reactivity** creates mongodb layer between neo4j and your meteor based application.
All requests is synchronized between all clients, as in real reactivity
```neo4j.query``` method returns reactive data source, data from Neo4j database will be in ```object.data``` property, if query has no data it is equals to ```null```

On [atmospherejs.com](https://atmospherejs.com/ostrio/neo4jreactivity)

### Install to meteor
```
meteor add ostrio:neo4jreactivity
```

### Usage (in helper)
```coffeescript
#CoffeeScript
Template.myView.created = ->
    Template.myView.helpers
        graph: () ->

            return neo4j.query 'MATCH (a:User)-[relation:friends]->(b:User)' +
                        'OPTIONAL MATCH (b:User)-[subrelation:friends]->()' +
                        'RETURN relation, subrelation', null, (error) ->
                if error
                     #handle error here
                     throw new Meteor.error '500', 'Something goes wrong here', error.toString()
```
### In view:
```html
<template name="myView">

    {{#each graph}}
       {{#each data}}
            <pre>
                {{relation.property}}, {{subrelation.property}}
            </pre>
        {{/each}}
    {{/each}}

</template>
```

### About security
To allow or deny actions use ```neo4j.set.allow(['array of strings'])``` and ```neo4j.set.deny(['array of strings'])```
```coffeescript
#CoffeeScript
neo4j.set.allow ['create', 'Remove']
neo4j.set.deny ['SKIP', 'LIMIT']

# default rules
neo4j.rules = 
    allow: ['RETURN', 'MATCH', 'SKIP', 'LIMIT', 'OPTIONAL', 'ORDER BY']
    deny: ['CREATE', 'UNIQUE', 'MERGE', 'SET', 'DELETE', 'REMOVE', 'FOREACH', 'WHERE', 'ON', 'INDEX', 'USING', 'DROP']
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
