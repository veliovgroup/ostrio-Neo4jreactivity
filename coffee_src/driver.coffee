@neo4j = {} if !@neo4j

neo4j.rules = 
    allow: ['RETURN', 'MATCH', 'SKIP', 'LIMIT', 'OPTIONAL', 'ORDER BY']
    deny: ['CREATE', 'UNIQUE', 'MERGE', 'SET', 'DELETE', 'REMOVE', 'FOREACH', 'WHERE', 'ON', 'INDEX', 'USING', 'DROP']

neo4j.set =
    allow: (rules) ->
        rules = @apply rules 
        neo4j.rules.allow = _.union neo4j.rules.allow, rules
        neo4j.rules.deny = _.difference neo4j.rules.deny, rules

    deny: (rules) ->
        rules = @apply rules 
        neo4j.rules.deny = _.union neo4j.rules.deny, rules
        neo4j.rules.allow = _.difference neo4j.rules.allow, rules

    apply: (rules) ->
        for key, val of rules
            rules[key] = val.toUpperCase()
        return rules

if Meteor.isServer
    Fiber = Npm.require("fibers")

    @N4JDB = new Neo4j()

    neo4j.run = (uid, query, opts, date, callback) ->
        neo4j.check query
        N4JDB.query query, opts, (error, data) ->
            return Fiber( ->
                callback(error, data) if callback
                if error
                    throw new Meteor.Error '500', 'N4JDB.query: [neo4j.run]', [error, uid, query, opts, callback].toString()
                    return null
                else    
                    neo4j.cache.put uid, data || null, date
            ).run()

    neo4j.cache = {} if !neo4j.cache

    neo4j.cache.put = (uid, data, date) ->
        Neo4jCacheCollection.upsert
            uid: uid
        ,
            uid: uid
            data: data
            created: date
        ,   (error) ->
            if error
                throw new Meteor.Error '500', 'Neo4jCacheCollection.insert: [neo4j.cache.put]', [error, uid, data].toString()
                return null

    neo4j.cache.get = (uid) ->
        Neo4jCacheCollection.find uid: uid


neo4j.query = (query, opts, callback) ->
    neo4j.check query
    uid = CryptoJS.SHA256(query).toString()
    if Meteor.isServer
        neo4j.run uid, query, opts, new Date(), callback
    else
        Meteor.call 'Neo4jRun', uid, query, opts, new Date(), callback, (error) ->
            if error
                throw new Meteor.Error '500', 'Calling method [Neo4jRun]', [error, query, opts, callback].toString()
                return null

    return Neo4jCacheCollection.find uid: uid

neo4j.check = (query) ->
    _.each neo4j.rules.deny, (value) ->
        _n = new RegExp value + ' ', "i"
        if query.search(_n) isnt -1
            throw new Meteor.Error '401', '[neo4j.check] "' + value + '" is not allowed!', query