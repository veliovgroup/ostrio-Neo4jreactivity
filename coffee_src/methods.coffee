if Meteor.isServer
    Meteor.methods
        Neo4jRun: (uid, query, opts, date, callback) ->
            neo4j.run uid, query, opts, date, callback

        Neo4jPut: (uid, data) ->
            neo4j.cache.put uid, data

        Neo4jGet: (uid) ->
            neo4j.cache.get uid