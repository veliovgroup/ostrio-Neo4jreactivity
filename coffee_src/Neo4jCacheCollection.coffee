@Neo4jCacheCollection = new Meteor.Collection 'Neo4jCache' ;

if Meteor.isServer
    Neo4jCacheCollection.allow
        insert: (userId, doc) ->
            doc.lastModified = doc.created = new Date()

        update: (userId, doc) ->
            false

        remove: (userId, doc) ->
            false

        fetch: ['owner']

    Meteor.publish 'Neo4jCacheCollection', -> 
        Neo4jCacheCollection.find 
            created: 
                $gte: new Date(new Date() - 5*60000)

if Meteor.isClient
    Meteor.subscribe 'Neo4jCacheCollection'