if Meteor.isServer
  ###
  # @server
  # @var {object} bound - Meteor.bindEnvironment aka Fiber wrapper
  ###
  bound = Meteor.bindEnvironment (callback) ->
    return callback()

  Meteor.N4JDB = {}
  @N4JDB = Meteor.N4JDB

###
# @isomorphic
# @object
# @namespace Meteor
# @name neo4j
# @description Create `neo4j` object
#
###
Meteor.neo4j =

  resultsCache: {}
  collections: {}
  onSubscribes: {}
  ###
  # @isomorphic
  # @namespace neo4j
  # @property allowClientQuery {Boolean}
  # @description Set to true to allow run queries from client
  #              Please, do not forget about security and 
  #              at least run Meteor.neo4j.set.deny(Meteor.neo4j.rules.write)
  ###
  allowClientQuery: false

  ###
  # @isomorphic
  # @function
  # @namespace neo4j
  # @name collection
  # @description Create Mongo like `neo4j` collection
  # @param name {String} - Name of collection/publish/subscription
  #
  ###
  collection: (name) ->
    collection = new Mongo.Collection null
    delete collection.update
    @collections[name] = collection
    @collections[name].allow
      update: () ->
        false
      insert: () ->
        true
      remove: () ->
        true
    return collection

  ###
  # @server
  # @function
  # @namespace neo4j
  # @name publish
  # @description Publish Mongo like `neo4j` collection
  # @param name {String}   - Name of collection/publish/subscription
  # @param func {Function} - Function with return Cypher query string, like: 
  #                          "return 'MATCH (a:User {name: {userName}}) RETURN a';"
  #
  ###
  publish: if Meteor.isServer then ((name, func, onSubscribe) ->
    method = {}
    method["Neo4jCache_#{name}"] = func
    @onSubscribes["Neo4jCacheOnSubscribe_#{name}"] = onSubscribe
    @methods method
  ) else undefined

  ###
  # @client
  # @function
  # @namespace neo4j
  # @name subscribe
  # @description Create Mongo like `neo4j` collection
  # @param {name} String - Name of collection/publish/subscription
  # @param opts {object|null}    - [NOT REQUIRED] A map of parameters for the Cypher query. 
  #                                Like: {userName: 'Joe'}, for query: 
  #                                "MATCH (a:User {name: {userName}}) RETURN a"
  # @param {link} String - Sub object name, like 'user' for query: "MATCH (user {_id: '183091'}) RETURN user"
  #
  ###
  subscribe: if Meteor.isClient then ((name, opts, link = false) ->
    self = @
    isReady = new ReactiveVar false
    throw new Meteor.Error '404', "[Meteor.neo4j.subscribe] | Collection: #{name} not found! | Use Meteor.neo4j.collection(#{name}) to create collection" if not @collections[name]

    @call "Neo4jCache_#{name}", opts, name, link, (error, data) ->
      throw new Meteor.Error '500', '[Meteor.neo4j.subscribe] | Error: ' + error.toString() if error
      self.collections[name].remove {}
      self.mapLink name, data, link
      isReady.set true

    return {
      ready: ->
        isReady.get()
    }
  ) else undefined

  ###
  # @isomorphic
  # @function
  # @namespace neo4j
  # @name mapLink
  # @description Create Mongo like `neo4j` collection
  # @param {name} String - Name of collection/publish/subscription
  # @param opts {object|null}    - [NOT REQUIRED] A map of parameters for the Cypher query. 
  #                                Like: {userName: 'Joe'}, for query: 
  #                                "MATCH (a:User {name: {userName}}) RETURN a"
  # @param {link} String - Sub object name, like 'user' for query: "MATCH (user {_id: '183091'}) RETURN user"
  #
  ###
  mapLink: (name, data, link) ->
    if data and not link
      keys = _.keys data
      rows = {}
      _.each keys, (element) ->
        _.each data[element], (value, key) ->
          if !rows[key]
            rows[key] = {}
          ext = {}
          ext[element] = value
          rows[key] = _.extend(rows[key], ext)

      _.each rows, (row) ->
        Meteor.neo4j.collections[name].insert row

    else if link and data[link]
      _.each data[link], (value) ->
        Meteor.neo4j.collections[name].insert value

  ###
  # @isomorphic
  # @function
  # @namespace neo4j
  # @name search
  # @param regexp   {RegExp}   - Regular Expression
  # @param string   {String}   - Haystack
  # @param callback {Function} - (OPTIONAL) Callback function(error, data) 
  # @description do search by RegExp in string
  # @returns {Boolean}
  #
  ###
  search: (regexp, string, callback) ->
    if string and string.search(regexp) != -1
      if callback then callback(true) else true
    else
      if callback then callback(false) else false

  ###
  # @isomorphic
  # @function
  # @namespace neo4j
  # @name check
  # @param query {String} - Cypher query
  # @description Check query for forbidden operators
  # @returns {undefined} or {throw new Meteor.Error(...)}
  #
  ###
  check: (query) ->
    if Meteor.isClient
      _n = undefined
      _.forEach @rules.deny, (value) ->
        _n = new RegExp(value + ' ', 'i')
        Meteor.neo4j.search _n, query, (isFound) ->
          if isFound
            throw new Meteor.Error '401', '[Meteor.neo4j.check] "' + value + '" is not allowed! | ' + [ query ].toString()

  ###
  # @isomorphic
  # @object
  # @namespace neo4j
  # @name rules
  # @property allow {Array}  - Array of allowed Cypher operators
  # @property deny  {Array}  - Array of forbidden Cypher operators
  # @property write {Array}  - Array of write Cypher operators
  # @description Bunch of Cypher operators
  #
  ###
  rules:
    allow: [
      'RETURN'
      'MATCH'
      'SKIP'
      'LIMIT'
      'OPTIONAL'
      'ORDER BY'
      'WITH'
      'AS'
      'WHERE'
      'CONSTRAINT'
      'UNWIND'
      'DISTINCT'
      'CASE'
      'WHEN'
      'THEN'
      'ELSE'
      'END'
      'CREATE'
      'UNIQUE'
      'MERGE'
      'SET'
      'DELETE'
      'REMOVE'
      'FOREACH'
      'ON'
      'INDEX'
      'USING'
      'DROP'
    ]
    deny: []
    write: [
      'CREATE'
      'SET'
      'DELETE'
      'REMOVE'
      'INDEX'
      'DROP'
      'MERGE'
    ]


  ###
  # @isomorphic
  # @object
  # @namespace neo4j
  # @name set
  # @description Methods to set allow/deny operators
  #
  ###
  set:
    ###
    # @isomorphic
    # @function
    # @namespace neo4j.set
    # @name allow
    # @param rules {Array} - Array of Cypher operators to be allowed in app
    #
    ###
    allow: (rules) ->
      if rules == '*'
        Meteor.neo4j.rules.allow = _.union(Meteor.neo4j.rules.allow, Meteor.neo4j.rules.deny)
        Meteor.neo4j.rules.deny = []
      else
        rules = @apply(rules)
        Meteor.neo4j.rules.allow = _.union(Meteor.neo4j.rules.allow, rules)
        Meteor.neo4j.rules.deny = _.difference(Meteor.neo4j.rules.deny, rules)

    ###
    # @isomorphic
    # @function
    # @namespace neo4j.set
    # @name deny
    # @param rules {Array} - Array of Cypher operators to be forbidden in app
    #
    ###
    deny: (rules) ->
      if rules == '*'
        Meteor.neo4j.rules.deny = _.union(Meteor.neo4j.rules.allow, Meteor.neo4j.rules.deny)
        Meteor.neo4j.rules.allow = []
      else
        rules = @apply(rules)
        Meteor.neo4j.rules.deny = _.union(Meteor.neo4j.rules.deny, rules)
        Meteor.neo4j.rules.allow = _.difference(Meteor.neo4j.rules.allow, rules)

    ###
    # @isomorphic
    # @function
    # @namespace neo4j.set
    # @name apply
    # @param rules {Array} - fix lowercased operators
    #
    ###
    apply: (rules) ->
      for k of rules
        rules[k] = rules[k].toUpperCase()
      rules

  ###
  # @isomorphic
  # @function
  # @namespace neo4j
  # @name mapParameters
  # @param query {String} - Cypher query
  # @param opts  {Object} - A map of parameters for the Cypher query
  # @description Isomorphic mapParameters for Neo4j query
  # @returns {String} - query with replaced map of parameters
  #
  ###
  mapParameters: (query, opts) ->
    _.forEach opts, (value, key) ->
      value = if !isNaN(value) then value else '"' + value + '"'
      query = query.replace('{' + key + '}', value).replace('{ ' + key + ' }', value)
    query

  ###
  # @isomorphic
  # @function
  # @namespace neo4j
  # @name query
  # @param query {string}      - Cypher query
  # @param opts {object}       - A map of parameters for the Cypher query
  # @param callback {function} - Callback function(error, data){...}
  # @description Isomorphic Cypher query call
  # @returns {object} | With get() method [REACTIVE DATA SOURCE]
  #
  ###
  query: (query, opts, callback) ->
    if opts
      query = @mapParameters query, opts
      opts = null

    @check query
    uid = Package.sha.SHA256 query
    cached = Meteor.neo4j.cacheCollection.find uid: uid
    if cached.fetch().length == 0 or @isWrite(query)
      if Meteor.isServer
        @run uid, query, opts, new Date
      else if @allowClientQuery == true and Meteor.isClient
        Meteor.call 'Neo4jRun', uid, query, opts, new Date, (error) ->
          if error
            throw new (Meteor.Error)('500', 'Calling method [Neo4jRun]: ' + [
              error
              query
              opts
            ].toString())
        Meteor.neo4j.uids.set _.union(Meteor.neo4j.uids.get(), [ uid ])
    @cache.get uid, callback

  ###
  # @isomorphic
  # @function
  # @namespace neo4j
  # @name isWrite
  # @param query {String} - Cypher query
  # @description Returns true if `query` writing/changing/removing data
  # @returns {Boolean}
  #
  ###
  isWrite: (query) ->
    _n = new RegExp '(' + @rules.write.join('|') + '*)', 'gi'
    @search _n, query

  ###
  # @isomorphic
  # @function
  # @namespace neo4j
  # @name isRead
  # @param query {String} - Cypher query
  # @description Returns true if `query` only reading
  # @returns {Boolean}
  #
  ###
  isRead: (query) ->
    _n = new RegExp '(' + @rules.write.join('|') + '*)', 'gi'
    !@search _n, query

  cache:
    ###
    # @isomorphic
    # @function
    # @namespace neo4j.cache
    # @name getObject
    # @param uid {String} - Unique hashed ID of the query
    # @description Get cached response by UID
    # @returns object
    #
    ###
    getObject: (uid) ->
      if Meteor.neo4j.allowClientQuery == true and Meteor.isClient or Meteor.isServer
        cache = Meteor.neo4j.cacheCollection.find(uid: uid)
        if Meteor.isServer
          if Meteor.neo4j.cacheCollection.findOne(uid: uid)
            Meteor.neo4j.resultsCache['NEO4JRES_' + uid] = Meteor.neo4j.cacheCollection.findOne(uid: uid).data
          cache.observe
            added: (doc) ->
              Meteor.neo4j.resultsCache['NEO4JRES_' + uid] = doc.data
            changed: (doc) ->
              Meteor.neo4j.resultsCache['NEO4JRES_' + uid] = doc.data
            removed: ->
              Meteor.neo4j.resultsCache['NEO4JRES_' + uid] = null
          return {
            cursor: cache
            get: ->
              Meteor.neo4j.resultsCache['NEO4JRES_' + uid]
          }
        else
          result = new ReactiveVar null
          if Meteor.neo4j.cacheCollection.findOne(uid: uid)
            result.set Meteor.neo4j.cacheCollection.findOne(uid: uid).data
          cache.observe
            added: (doc) ->
              result.set doc.data
            changed: (doc) ->
              result.set doc.data
            removed: ->
              result.set null
          return {
            cursor: cache
            get: ->
              result.get()
          }

    ###
    # @isomorphic
    # @function
    # @namespace neo4j.cache
    # @name get
    # @param uid      {String}   - Unique hashed ID of the query
    # @param callback {Function} - Callback function(error, data){...}.
    # @description Get cached response by UID
    # @returns object
    #
    ###
    get: (uid, callback) ->
      if Meteor.neo4j.allowClientQuery == true and Meteor.isClient
        if callback
          Tracker.autorun ->
            result = Meteor.neo4j.cacheCollection.findOne(uid: uid)
            if result and result.data
              callback and callback null, result.data
      else
        if callback
          if !Meteor.neo4j.cacheCollection.findOne(uid: uid)
            Meteor.neo4j.cacheCollection.find(uid: uid).observe added: ->
              callback null, Meteor.neo4j.cacheCollection.findOne(uid: uid).data
          else
            callback null, Meteor.neo4j.cacheCollection.findOne(uid: uid).data
      Meteor.neo4j.cache.getObject uid

    ###
    # @isomorphic
    # @function
    # @namespace neo4j.cache
    # @name put
    # @param uid  {String}         - Unique hashed ID of the query
    # @param data {Object}         - Data returned from neo4j (Cypher query response)
    # @param queryString {String}  - Cypher query
    # @param opts {Object}         - A map of parameters for the Cypher query
    # @param date {Date}           - Creation date
    # @description Upsert reactive mongo cache collection
    #
    ###
    put: if Meteor.isServer then ((uid, data, queryString, opts, date) ->
      Meteor.neo4j.cacheCollection.upsert { uid: uid }, {
        uid: uid
        data: Meteor.neo4j.parseReturn(data, queryString)
        query: queryString
        sensitivities: Meteor.neo4j.parseSensitivities(queryString, opts)
        opts: opts
        type: if Meteor.neo4j.isWrite(queryString) then 'WRITE' else 'READ'
        created: date
      }, (error) ->
        if error
          throw new Meteor.Error '500', 'Meteor.neo4j.cacheCollection.upsert: [Meteor.neo4j.cache.put]: ' + [
            error
            uid
            data
            queryString
            opts
            date
          ].toString()
    ) else undefined

  ###
  # @client
  # @function
  # @namespace neo4j
  # @name init
  # @description connect to neo4j DB and set listeners
  ###
  init: if Meteor.isServer then ((url) ->
    if url and @connectionURL == null
      @connectionURL = url

    ###
    # @description Connect to Neo4j database, returns GraphDatabase object
    ###
    Meteor.N4JDB = new Meteor.Neo4j Meteor.neo4j.connectionURL

    ###
    #
    # @callback
    # @description Listen for all requests to Neo4j
    # if request is writing/changing/removing data
    # we will find all sensitive data and update 
    # all subscribed records at Meteor.neo4j.cacheCollection
    #
    ###
    Meteor.N4JDB.listen (query, opts) ->
      if Meteor.neo4j.isWrite(query)
        sensitivities = Meteor.neo4j.parseSensitivities(query, opts)
        if sensitivities
          affectedRecords = Meteor.neo4j.cacheCollection.find(
            sensitivities: '$in': sensitivities
            type: 'READ')
          bound (->
            affectedRecords.forEach (value) ->
              Meteor.neo4j.run value.uid, value.query, value.opts, value.created
          )
  ) else undefined

  ###
  # @server
  # @function
  # @namespace neo4j
  # @name run
  # @param uid    {String} - Unique hashed ID of the query
  # @param query  {String} - Cypher query
  # @param opts   {Object} - A map of parameters for the Cypher query
  # @param date   {Date}   - Creation date
  # @description Run Cypher query, handle response with Fibers
  #
  ###
  run: if Meteor.isServer then ((uid, query, opts, date) ->
    @check query
    Meteor.N4JDB.query query, opts, (error, data) ->
      bound (->
        if error
          throw new Meteor.Error '500', 'Meteor.N4JDB.query: [Meteor.neo4j.run]: ' + [
            error
            uid
            query
            opts
            date
          ].toString()
        else
          return Meteor.neo4j.cache.put(uid, data or null, query, opts, date)
      )
  ) else undefined

  ###
  # @server
  # @function
  # @namespace neo4j
  # @name parseReturn
  # @param data {Object} - Cypher query response, neo4j database response
  # @description Parse returned object from neo4j
  # @returns {Object}
  #
  ###
  parseReturn: if Meteor.isServer then ((data, queryString) ->
    data = data.map (result) ->
      _.each result, (value, key, list) ->
        if key.indexOf('.') != -1
          list[key.replace('.', '_')] = value
          delete list[key]
      result

    _res = undefined
    _data = data
    _originals = []
    _clauses = undefined
    wait = undefined
    _n = new RegExp('return ', 'i')
    wait = @search _n, queryString, (isFound) ->
      if isFound
        _data = {}
        _res = queryString.replace(/.*return /i, '').trim()
        _res = _res.split(',')
        i = _res.length - 1
        while i >= 0
          if _res[i].indexOf('.') != -1
            _res[i] = _res[i].replace '.', '_'
          i--
        _res = _res.map(((str) ->
          str = str.trim()
          if str.indexOf(' AS ') != -1
            str = _.last str.split ' '
          str
        ))
        _clauses = _.last(_res)
        if _clauses.indexOf(' ') != -1
          _clause = _.first _clauses.split ' '
          _res[_res.length - 1] = _clause
        for i of _res
          `i = i`
          _res[i] = _res[i].trim()
          _originals[i] = _res[i]
          if _res[i].indexOf(' ') != -1
            _res[i] = _.last _res[i].split ' '
            _originals[i] = _.first _res[i].split ' '
          _data[_res[i]] = []

        data.map (result) ->
          for i of _res
            `i = i`
            if ! !result[_res[i]]
              if _res[i].indexOf('(') != -1 and _res[i].indexOf(')') != -1
                _data[_res[i]] = result[_res[i]]
              else if _originals[i].indexOf('.') != -1 or _.isString(result[_res[i]]) or _.isNumber(result[_res[i]]) or _.isBoolean(result[_res[i]]) or _.isDate(result[_res[i]]) or _.isNaN(result[_res[i]]) or _.isNull(result[_res[i]]) or _.isUndefined(result[_res[i]])
                _data[_res[i]].push result[_res[i]]
              else
                if ! !result[_res[i]].data and ! !result[_res[i]]._data and ! !result[_res[i]]._data.metadata
                  result[_res[i]].data.metadata = result[_res[i]]._data.metadata
                if ! !result[_res[i]]._data and ! !result[_res[i]]._data.start and ! !result[_res[i]]._data.end and ! !result[_res[i]]._data.type
                  result[_res[i]].data.relation =
                    extensions: result[_res[i]]._data.extensions
                    start: _.last result[_res[i]]._data.start.split '/'
                    end: _.last result[_res[i]]._data.end.split '/'
                    self: _.last result[_res[i]]._data.self.split '/'
                    type: result[_res[i]]._data.type
                if ! !result[_res[i]].data
                  _data[_res[i]].push result[_res[i]].data

    @returns = _res
    _data
  ) else undefined

  ###
  # @server
  # @function
  # @namespace neo4j
  # @name parseSensitivities
  # @param query {String}  - Cypher query
  # @param opts {Object}   - A map of parameters for the Cypher query.
  # @description Parse Cypher query for sensitive data
  # @returns {Array}
  #
  ###
  parseSensitivities: if Meteor.isServer then ((query, opts) ->
    _n = new RegExp(/"([a-zA-z0-9]*)"|'([a-zA-z0-9]*)'|:[^\'\"\ ](\w*)/gi)
    matches = undefined
    result = []
    while matches = _n.exec query
      if matches[0]
        result.push matches[0].replace(/["']/gi, '')
    if opts
      _.forEach opts, (value, key) ->
        result.push value
        result.push key
    result
  ) else undefined


  ###
  # @server
  # @function
  # @namespace neo4j
  # @name methods
  # @param methods {Object} - Object of methods, like: 
  #                              methodName: -> 
  #                                return 'MATCH (a:User {name: {userName}}) RETURN a'
  # @description Create server methods to send query to neo4j database
  #
  ###
  methods: if Meteor.isServer then ((methods) ->
    self = @
    _methods = {}
    _.forEach methods, (query, methodName) ->
      _methods[methodName] = (opts, name, link) ->
        _query = query()
        if opts
          _query = self.mapParameters _query, opts
          opts = null
        uid = Package.sha.SHA256 _query
        if name
          self.query _query, opts, (error, data) ->
            throw new Meteor.Error '500', "[Meteor.neo4j.methods] | Error: " + error.toString() if error
            throw new Meteor.Error '404', "[Meteor.neo4j.methods] | Collection: #{name} not found! | Use Meteor.neo4j.collection(#{name}) to create collection" if not self.collections[name]
            self.collections[name].remove {}
            self.mapLink name, data, link

          self.onSubscribes["Neo4jCacheOnSubscribe_#{name}"]() if self.onSubscribes["Neo4jCacheOnSubscribe_#{name}"] and _.isFunction self.onSubscribes["Neo4jCacheOnSubscribe_#{name}"]
        else
          self.query _query, opts
        return uid

    Meteor.methods _methods
  ) else undefined

  ###
  # @clinet
  # @function
  # @namespace neo4j
  # @name call
  # @param methodName {String}   - method name registered via neo4j.methods() method
  # @param opts {Object|null}    - [NOT REQUIRED] A map of parameters for the Cypher query. 
  #                                Like: {userName: 'Joe'}, for query like: MATCH (a:User {name: {userName}}) RETURN a
  # @param callback {function}   - Callback function(error, data){...}.
  # @description Call for server method registered via neo4j.methods() method, 
  #              returns error, data via callback.
  # @returns {Object} | With get() method [REACTIVE DATA SOURCE]
  #
  ###
  call: if Meteor.isClient then ((methodName, opts, name, link) ->
    for param in arguments
      callback = param if _.isFunction param

    Meteor.call methodName, opts, name, link, (error, uid) ->
      if error
        throw new Meteor.Error '500', '[Meteor.neo4j.call] Method: ["' + methodName + '"] returns error! | ' + [ error ].toString()
      else
        Meteor.neo4j.uids.set _.union(Meteor.neo4j.uids.get(), [ uid ])
        return Meteor.neo4j.cache.get(uid, callback)
  ) else undefined

###
# @description Create Meteor.neo4j.uids ReactiveVar
###
if Meteor.isClient
  Meteor.neo4j.uids = new ReactiveVar []

###
# @isomorphic
# @namespace neo4j
# @property connectionURL {String} - url to Neo4j database
# @description Set connection URL to Neo4j Database
###
connectionURL = null
Object.defineProperty Meteor.neo4j, 'connectionURL',
  get: ->
    connectionURL
  set: (val) ->
    if val != connectionURL
      connectionURL = val
      if Meteor.isServer
        Meteor.neo4j.init()
    return
  configurable: false
  enumerable: false

@neo4j = Meteor.neo4j

if Meteor.isServer
  ###
  # @description Initialize connection to Neo4j
  ###
  Meteor.neo4j.init()