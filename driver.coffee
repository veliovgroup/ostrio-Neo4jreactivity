if Meteor.isServer
  ###
  # @server
  # @var {object} bound - Meteor.bindEnvironment aka Fiber wrapper
  ###
  bound = Meteor.bindEnvironment (callback) ->
    return callback()

  Meteor.N4JDB = {}

###
# @isomorphic
# @object
# @namespace Meteor
# @name neo4j
# @description Create `neo4j` object
#
###
Meteor.neo4j =

  ready: false
  resultsCache: {}
  collections: {}
  onSubscribes: {}
  subscriptions: {}

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
  # @param collectionName {String} - Collection name
  # @description Create Mongo like `neo4j` collection
  # @param name {String} - Name of collection/publish/subscription
  #
  ###
  collection: (collectionName) ->
    check collectionName, String

    collection = new Mongo.Collection null
    @collections[collectionName] = {}
    @collections[collectionName].isMapping = false
    @collections[collectionName].collection = collection
    @collections[collectionName].collection.allow
      update: () ->
        true
      insert: () ->
        true
      remove: () ->
        true

    cursor = collection.find {}
    getLabels = (doc) ->
      return switch
        when _.isObject(doc) and !!doc.__labels and doc.__labels.indexOf(':') is 0 then doc.__labels
        when _.isArray doc
          labelsArr = (record.__labels for record in doc when _.has record, '__labels')
          labelsArr = _.uniq labelsArr
          labelsArr.join ''
        else
          ''

    if Meteor.isServer
      cursor.observe
        added: (doc) ->
          labels = getLabels doc
          if not Meteor.neo4j.collections[collectionName].isMapping
            delete doc.__labels if _.has doc, '__labels'
            delete doc.metadata if _.has doc, 'metadata'
            Meteor.neo4j.query "MATCH (n#{labels} {_id: {_id}}) WITH count(n) AS count_n WHERE count_n <= 0 CREATE (n#{labels} {properties})", {properties: doc, _id: doc._id}
        changed: (doc, old) ->
          labels = getLabels doc
          if not Meteor.neo4j.collections[collectionName].isMapping
            delete doc.__labels if _.has doc, '__labels'
            delete doc.metadata if _.has doc, 'metadata'
            Meteor.neo4j.query "MATCH (n#{labels} {_id: {_id}}) SET n = {properties}", {_id: old._id, properties: doc}
        removed: (doc) ->
          labels = getLabels doc
          if not Meteor.neo4j.collections[collectionName].isMapping
            delete doc.__labels if _.has doc, '__labels'
            delete doc.metadata if _.has doc, 'metadata'
            Meteor.neo4j.query "MATCH (n#{labels} {_id: {_id}}) DELETE n", {_id: doc._id}
    else
      cursor.observe
        added: (doc) ->
          labels = getLabels doc
          if not Meteor.neo4j.collections[collectionName].isMapping
            delete doc.__labels if _.has doc, '__labels'
            delete doc.metadata if _.has doc, 'metadata'
            Meteor.neo4j.call '___Neo4jObserveAdded', {properties: doc, _id: doc._id, __labels: labels}, collectionName, doc, (error) ->
              if error
                console.error {error, collectionName}
                throw new Meteor.Error 500, '[___Neo4jObserveRemoved]'
        changed: (doc, old) ->
          labels = getLabels doc
          if not Meteor.neo4j.collections[collectionName].isMapping
            delete doc.__labels if _.has doc, '__labels'
            delete doc.metadata if _.has doc, 'metadata'
            Meteor.neo4j.call '___Neo4jObserveChanged', {_id: old._id, properties: doc, __labels: labels}, collectionName, doc, (error) ->
              if error
                console.error {error, collectionName}
                throw new Meteor.Error 500, '[___Neo4jObserveRemoved]'
        removed: (doc) ->
          labels = getLabels doc
          if not Meteor.neo4j.collections[collectionName].isMapping
            delete doc.__labels if _.has doc, '__labels'
            delete doc.metadata if _.has doc, 'metadata'
            Meteor.neo4j.call '___Neo4jObserveRemoved', {_id: doc._id, __labels: labels}, collectionName, doc, (error) ->
              if error
                console.error {error, collectionName}
                throw new Meteor.Error 500, '[___Neo4jObserveRemoved]'

    if Meteor.isServer
      collection.publish = (name, func, onSubscribe) ->
        Meteor.neo4j.publish collectionName, name, func, onSubscribe

    else
      collection.subscribe = (name, opts, link = false) ->
        Meteor.neo4j.subscribe collectionName, name, opts, link

    return collection


  ###
  # @server
  # @function
  # @namespace neo4j
  # @name publish
  # @description Publish Mongo like `neo4j` collection
  # @param collectionName {String} - Collection name
  # @param name {String}           - Name of publish/subscription
  # @param func {Function}         - Function with return Cypher query string, like: 
  #                                  "return 'MATCH (a:User {name: {userName}}) RETURN a';"
  # @param onSubscribe {Function}  - Callback function triggered after
  #                                  client is subscribed on published data
  #
  ###
  publish: if Meteor.isServer then ((collectionName, name, func, onSubscribe) ->
    check collectionName, String
    check name, String
    check func, Function
    check onSubscribe, Match.Optional Match.OneOf Function, null

    method = {}
    method["Neo4jReactiveMethod_#{collectionName}_#{name}"] = func
    @subscriptions["#{collectionName}_#{name}"] ?= []
    @onSubscribes["#{collectionName}_#{name}"] = onSubscribe
    @methods method
  ) else undefined

  ###
  # @client
  # @function
  # @namespace neo4j
  # @name subscribe
  # @description Create Mongo like `neo4j` collection
  # @param collectionName {String} - Collection name
  # @param name {String}           - Name of publish/subscription
  # @param opts {object|null}      - [NOT REQUIRED] A map of parameters for the Cypher query. 
  #                                  Like: {userName: 'Joe'}, for query: 
  #                                  "MATCH (a:User {name: {userName}}) RETURN a"
  # @param link {String}           - Sub object name, like 'user' for query: 
  #                                  "MATCH (user {_id: '183091'}) RETURN user"
  #
  ###
  subscribe: if Meteor.isClient then ((collectionName, name, opts, link) ->
    check collectionName, String
    check name, String
    check opts, Match.Optional Match.OneOf Object, null
    check link, String

    isReady = new ReactiveVar false
    throw new Meteor.Error 404, "[Meteor.neo4j.subscribe] | Collection: #{collectionName} not found! | Use Meteor.neo4j.collection(#{collectionName}) to create collection" if not @collections[collectionName]

    @subscriptions["#{collectionName}_#{name}"] ?= []

    @call "Neo4jReactiveMethod_#{collectionName}_#{name}", opts, collectionName, link, (error, data) =>
      if error
        console.error {error, collectionName, name, opts, link}
        throw new Meteor.Error 500, '[Meteor.neo4j.subscribe]'
      @mapLink collectionName, data, link, "#{collectionName}_#{name}"
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
  # @param collectionName {String} - Name of collection
  # @param data {Object|null}      - Returned data from Neo4j
  # @param link {String}           - Sub object name, like 'user' for query: "MATCH (user {_id: '183091'}) RETURN user"
  # @param subsName {String}       - Subscription name - collection name + subscription/publish
  #
  ###
  mapLink: (collectionName, data, link, subsName) ->
    check collectionName, String
    check data, Match.Optional Match.OneOf Object, null
    check link, String
    check subsName, String

    if link and data?[link]
      if @subscriptions[subsName] and not _.isEmpty @subscriptions[subsName]
        oldIds = (doc._id for doc in @subscriptions[subsName])
        newIds = (doc._id for doc in data[link])

        diff = _.difference oldIds, newIds
        if diff and not _.isEmpty diff
          @collections[collectionName].isMapping = true
          @collections[collectionName].collection.remove
            _id: 
              $in: diff
          ,
           () =>
            @collections[collectionName].isMapping = false

        @subscriptions[subsName] = []

      _.each data[link], (doc) =>
        @collections[collectionName].isMapping = true

        if not doc._id
          _id = Random.id()
        else
          _id = doc._id

        doc._id = _.clone _id

        @subscriptions[subsName].push _.clone doc

        delete doc._id
        delete doc._data
        delete doc.data
        @collections[collectionName].collection.upsert
          _id: _id
        , 
          $set: doc
        , 
         () =>
          @collections[collectionName].isMapping = false

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
    check query, String
    if Meteor.isClient
      _n = undefined
      _.each @rules.deny, (value) =>
        _n = new RegExp(value + ' ', 'i')
        @search _n, query, (isFound) ->
          if isFound
            console.warn {query}
            throw new Meteor.Error 401, '[Meteor.neo4j.check] "#{value}" is not allowed!'

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
      check rules, Match.OneOf [String], '*'

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
      check rules, Match.OneOf [String], '*'

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
      check rules, Match.OneOf [String], '*'

      for k of rules
        rules[k] = rules[k].toUpperCase()
      rules

  ###
  # @isomorphic
  # @function
  # @namespace neo4j
  # @name query
  # @param query {String}      - Cypher query
  # @param opts {Object}       - A map of parameters for the Cypher query
  # @param callback {Function} - Callback function(error, data){...}
  # @description Isomorphic Cypher query call
  # @returns {Object} | With get() method [REACTIVE DATA SOURCE]
  #
  ###
  query: (query, opts, callback) ->
    check query, String
    check opts, Match.Optional Match.OneOf Object, null
    check callback, Match.Optional Match.OneOf Function, null

    @check query
    uid = Package.sha.SHA256 query
    optuid = Package.sha.SHA256 query + JSON.stringify opts
    cached = @cacheCollection.find {uid}
    if Meteor.isClient and cached.fetch().length > 0
      _uids = @uids.get()
      _.each cached.fetch(), (row) ->
        _uids = _.without _uids, row.optuid unless row.optuid is optuid
      @uids.set _uids
    cached = @cacheCollection.find {optuid}
    if cached.fetch().length <= 0 or @isWrite(query)
      if Meteor.isServer
        @run uid, optuid, query, opts, new Date
      else if @allowClientQuery == true and Meteor.isClient
        Meteor.call 'Neo4jRun', uid, optuid, query, opts, new Date, (error) ->
          if error
            console.error {error, query, opts}
            throw new Meteor.Error 500, 'Exception on calling method [Neo4jRun]'
        @uids.set _.union(@uids.get(), [ optuid ])
    @cache.get optuid, callback

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
    check query, String
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
    check query, String
    _n = new RegExp '(' + @rules.write.join('|') + '*)', 'gi'
    !@search _n, query

  cache:
    ###
    # @isomorphic
    # @function
    # @namespace neo4j.cache
    # @name getObject
    # @param optuid {String} - Unique hashed ID of the query
    # @description Get cached response by optuid
    # @returns object
    #
    ###
    getObject: (optuid, callback) ->
      check optuid, String
      check callback, Match.Optional Match.OneOf Function, null

      if callback and _.isFunction callback
        cbWrapper = (error, data) ->
          _uids = Meteor.neo4j.uids.get()
          if !!~_uids.indexOf optuid
            callback error, data
      else
        cbWrapper = -> null

      if Meteor.neo4j.allowClientQuery == true and Meteor.isClient or Meteor.isServer
        cache = Meteor.neo4j.cacheCollection.find {optuid}
        if Meteor.isServer
          if cache.fetch().length > 0
            Meteor.neo4j.resultsCache['NEO4JRES_' + optuid] = cache.fetch()[0].data

          cache.observe
            added: (doc) ->
              cbWrapper null, doc.data
              Meteor.neo4j.resultsCache['NEO4JRES_' + optuid] = doc.data
            changed: (doc) ->
              cbWrapper null, doc.data
              Meteor.neo4j.resultsCache['NEO4JRES_' + optuid] = doc.data
            removed: ->
              cbWrapper()
              Meteor.neo4j.resultsCache['NEO4JRES_' + optuid] = null
          res =
            cursor: cache
            get: ->
              Meteor.neo4j.resultsCache['NEO4JRES_' + optuid]
        else
          result = new ReactiveVar null
          _findOne = cache.fetch()[0]?.data

          if _findOne
            result.set _findOne.data

          cache.observe
            added: (doc) ->
              cbWrapper null, doc.data
              result.set doc.data
            changed: (doc) ->
              cbWrapper null, doc.data
              result.set doc.data
            removed: ->
              cbWrapper()
              result.set null
          res =
            cursor: cache
            get: ->
              result.get()

        return res
    ###
    # @isomorphic
    # @function
    # @namespace neo4j.cache
    # @name get
    # @param optuid   {String}   - Unique hashed ID of the query
    # @param callback {Function} - Callback function(error, data){...}.
    # @description Get cached response by UID
    # @returns object
    #
    ###
    get: (optuid, callback) ->
      check optuid, String
      check callback, Match.Optional Match.OneOf Function, null

      Meteor.neo4j.cache.getObject optuid, callback

    ###
    # @isomorphic
    # @function
    # @namespace neo4j.cache
    # @name put
    # @param uid    {String}       - Unique hashed ID of the query
    # @param optuid {String}       - Unique hashed ID of the query with options
    # @param data   {Object}       - Data returned from neo4j (Cypher query response)
    # @param queryString {String}  - Cypher query
    # @param opts {Object}         - A map of parameters for the Cypher query
    # @param date {Date}           - Creation date
    # @description Upsert reactive mongo cache collection
    #
    ###
    put: if Meteor.isServer then ((uid, optuid, data, queryString, opts, date) ->
      check uid, String
      check optuid, String
      check data, Match.Optional Match.OneOf [Object], null
      check queryString, String
      check opts, Match.Optional Match.OneOf Object, null
      check date, Date

      parsedData = Meteor.neo4j.parseReturn data, queryString
      Meteor.neo4j.cacheCollection.upsert
        optuid: optuid
      ,
        uid:      uid
        optuid:   optuid
        data:     parsedData
        query:    queryString
        opts:     opts
        type:     if Meteor.neo4j.isWrite queryString then 'WRITE' else 'READ'
        created:  date
        sensitivities: Meteor.neo4j.parseSensitivities queryString, opts, parsedData
      , 
        (error) ->
          if error
            console.error {error, uid, optuid, data, queryString, opts, date}
            throw new Meteor.Error 500, 'Meteor.neo4j.cacheCollection.upsert: [Meteor.neo4j.cache.put]'
    ) else undefined

  ###
  # @server
  # @function
  # @namespace neo4j
  # @name init
  # @description connect to neo4j DB and set listeners
  ###
  init: if Meteor.isServer then ((url) ->
    check url, Match.Optional Match.OneOf String, null
    @connectionURL = url if url and @connectionURL == null

    ###
    # @description Connect to Neo4j database, returns GraphDatabase object
    ###
    Meteor.N4JDB = new Meteor.Neo4j @connectionURL

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
      bound ->
        if Meteor.neo4j.isWrite query
          sensitivities = Meteor.neo4j.parseSensitivities query, opts
          if sensitivities
            affectedRecords = Meteor.neo4j.cacheCollection.find
              sensitivities: 
                $in: sensitivities
              type: 'READ'

            affectedRecords.forEach (doc) ->
              Meteor.neo4j.run doc.uid, doc.optuid, doc.query, doc.opts, doc.created

    @ready = true
  ) else undefined

  ###
  # @server
  # @function
  # @namespace neo4j
  # @name run
  # @param uid    {String} - Unique hashed ID of the query
  # @param optuid {String} - Unique hashed ID of the query with options
  # @param query  {String} - Cypher query
  # @param opts   {Object} - A map of parameters for the Cypher query
  # @param date   {Date}   - Creation date
  # @description Run Cypher query, handle response with Fibers
  #
  ###
  run: if Meteor.isServer then ((uid, optuid, query, opts, date) ->
    check uid, String
    check optuid, String
    check query, String
    check opts, Match.Optional Match.OneOf Object, null
    check date, Date

    @check query
    Meteor.N4JDB.query query, opts, (error, data) ->
      bound ->
        if error
          console.error {error, uid, optuid, query, opts, date}
          throw new Meteor.Error 500, '[Meteor.N4JDB.query]'
        else
          return Meteor.neo4j.cache.put uid, optuid, data or null, query, opts, date
  ) else undefined

  ###
  # @server
  # @function
  # @namespace neo4j
  # @name parseReturn
  # @param data {Object}        - Cypher query response, neo4j database response
  # @param queryString {String} - Cypher query string
  # @description Parse returned object from neo4j
  # @returns {Object}
  #
  ###
  parseReturn: if Meteor.isServer then ((data, queryString) ->
    check data, [Object]  
    check queryString, String

    cleanData = (result) ->
      for key, value of result when !!~key.indexOf('.')
        result[key.replace('.', '_')] = value
        delete result[key]
      result

    _data = (cleanData(result) for result in data)

    _res = undefined
    _originals = []
    _n = new RegExp('return ', 'i')
    @search _n, queryString, (isFound) ->
      if isFound
        _data = {}
        _res = queryString.replace(/.*return /i, '').trim()
        _res = _res.split(',')
        i = _res.length - 1

        while i >= 0
          if !!~_res[i].indexOf('.')
            _res[i] = _res[i].replace '.', '_'
          i--


        _res = for str in _res
          str = str.trim()
          if !!~str.indexOf ' AS '
            str = _.last str.split ' '
          str

        _clauses = _.last(_res)
        if !!~_clauses.indexOf(' ')
          _clause = _.first _clauses.split ' '
          _res[_res.length - 1] = _clause

        for i of _res
          _res[i] = _res[i].trim()
          _originals[i] = _res[i]
          if !!~_res[i].indexOf(' ')
            _res[i] = _.last _res[i].split ' '
            _originals[i] = _.first _res[i].split ' '
          _data[_res[i]] = []

        for result in data
          for i of _res
            if !!result[_res[i]]
              switch
                when !!~_res[i].indexOf('(') and !!~_res[i].indexOf(')')
                  _data[_res[i]] = result[_res[i]]
                when !!~_originals[i].indexOf('.') or _.isString(result[_res[i]]) or _.isNumber(result[_res[i]]) or _.isBoolean(result[_res[i]]) or _.isDate(result[_res[i]]) or _.isNaN(result[_res[i]]) or _.isNull(result[_res[i]]) or _.isUndefined(result[_res[i]])
                  _data[_res[i]].push result[_res[i]]
                else
                  if !!result[_res[i]].data and !!result[_res[i]]._data and !!result[_res[i]]._data.metadata
                    result[_res[i]].data.metadata = result[_res[i]]._data.metadata

                  if !!result[_res[i]]._data and !!result[_res[i]]._data.start and !!result[_res[i]]._data.end and !!result[_res[i]]._data.type
                    result[_res[i]].data.relation =
                      extensions: result[_res[i]]._data.extensions
                      start: _.last result[_res[i]]._data.start.split '/'
                      end: _.last result[_res[i]]._data.end.split '/'
                      self: _.last result[_res[i]]._data.self.split '/'
                      type: result[_res[i]]._data.type

                  if !!result[_res[i]].data
                    _data[_res[i]].push result[_res[i]].data

    @returns = _res
    _data
  ) else undefined

  ###
  # @server
  # @function
  # @namespace neo4j
  # @name parseSensitivities
  # @param query {String}        - Cypher query
  # @param opts  {Object}        - [Optional] A map of parameters for the Cypher query.
  # @param parsedData {[Object]} - [Optional] Array of parsed objects returned from Neo4j
  # @description Parse Cypher query for sensitive data
  # @returns {[String]}
  #
  ###
  parseSensitivities: if Meteor.isServer then ((query, opts, parsedData) ->
    check query, String
    check opts, Match.Optional Match.OneOf Object, null

    result = []

    checkForId = (set) ->
      result.push doc._id for key, doc of set when _.has doc, '_id'

    checkForId(set) for key, set of parsedData when set and _.isObject set if parsedData and not _.isEmpty parsedData

    _n = new RegExp(/"([a-zA-z0-9]*)"|'([a-zA-z0-9]*)'|:[^\'\"\ ](\w*)/gi)

    result.push matches[0].replace(/["']/gi, '') while matches = _n.exec query when matches[0]
    result.push value for key, value of opts when _.isString value if opts
    result = _.uniq result
    return (res for res in result when !!res.length)
  ) else undefined


  ###
  # @server
  # @function
  # @namespace neo4j
  # @name methods
  # @param methods {Object} - Object of methods, like: 
  #                            methodName: -> 
  #                              return 'MATCH (a:User {name: {userName}}) RETURN a'
  # @description Create server methods to send query to neo4j database
  #
  ###
  methods: if Meteor.isServer then ((methods) ->
    check methods, Object

    self = @
    _methods = {}
    _.each methods, (query, methodName) ->
      _methods[methodName] = (opts, collectionName, link) ->
        check opts, Match.Optional Match.OneOf Object, null
        check collectionName, Match.Optional Match.OneOf String, null
        check link, Match.Optional Match.OneOf String, null

        _cmn = if methodName.indexOf('Neo4jReactiveMethod_') isnt -1 then methodName.replace 'Neo4jReactiveMethod_', '' else methodName
        _query = query.call opts

        uid = Package.sha.SHA256 _query
        optuid = Package.sha.SHA256 _query + JSON.stringify opts
        if collectionName
          self.query _query, opts, (error, data) ->
            if error
              console.error {error, uid, optuid, query, opts, date}
              throw new Meteor.Error 500, "[Meteor.neo4j.methods]"
            throw new Meteor.Error 404, "[Meteor.neo4j.methods] | Collection: #{collectionName} not found! | Use Meteor.neo4j.collection(#{collectionName}) to create collection" if not self.collections[collectionName]
            self.mapLink collectionName, data, link, _cmn
          self.onSubscribes[_cmn].call(opts) if self.onSubscribes[_cmn] and _.isFunction self.onSubscribes[_cmn]
        else
          self.query _query, opts

        return {optuid, uid, isWrite: self.isWrite(_query), isRead: self.isRead(_query)}

    Meteor.methods _methods
  ) else undefined

  ###
  # @server
  # @function
  # @namespace neo4j
  # @name methods
  # @param methods {Object} - Special service methods for reactive mini-neo4j
  #
  ###
  ___methods: if Meteor.isServer then ((methods) ->
    check methods, Object

    self = @
    _methods = {}
    _.each methods, (query, methodName) ->
      _methods[methodName] = (opts, collectionName, doc) ->
        check opts, Match.Optional Match.OneOf Object, null
        check collectionName, String
        check doc, Object

        if methodName is '___Neo4jObserveAdded'
          self.collections[collectionName].isMapping
          self.collections[collectionName].collection.insert doc, () ->
            self.collections[collectionName].isMapping = false

        if methodName is '___Neo4jObserveChanged'
          delete doc._id
          self.collections[collectionName].isMapping = true
          self.collections[collectionName].collection.update opts._id, $set: doc, () ->
            self.collections[collectionName].isMapping = false

        if methodName is '___Neo4jObserveRemoved'
          self.collections[collectionName].isMapping = true
          self.collections[collectionName].collection.remove opts._id, () ->
            self.collections[collectionName].isMapping = false

        _query = query.call opts
        uid = Package.sha.SHA256 _query
        optuid = Package.sha.SHA256 _query + JSON.stringify opts
        self.query _query, opts
        return {optuid, uid, isWrite: self.isWrite(_query), isRead: self.isRead(_query)}

    Meteor.methods _methods
  ) else undefined

  ###
  # @isomorphic
  # @function
  # @namespace neo4j
  # @name call
  # @param methodName {String}   - method name registered via neo4j.methods() method
  # @param opts {Object|null}    - [NOT REQUIRED] A map of parameters for the Cypher query. 
  #                                Like: {userName: 'Joe'}, for query like: MATCH (a:User {name: {userName}}) RETURN a
  # @param name {String}         - Collection name
  # @param link {String}         - Sub object name, like 'user' for query: 
  #                                "MATCH (user {_id: '183091'}) RETURN user"
  # @description Call for server method registered via neo4j.methods() method, 
  #              returns error, data via callback.
  # @returns {Object} | With get() method [REACTIVE DATA SOURCE]
  #
  ###
  call: (methodName, opts, name, link) ->
    check methodName, String
    check opts, Match.Optional Match.OneOf Object, null

    callback = param for param in arguments when _.isFunction param

    Meteor.call methodName, opts, name, link, (error, uids) =>
      if error
        console.error {error, methodName, opts, name, link}
        throw new Meteor.Error '500', "[Meteor.neo4j.call] Method: [\"#{methodName}\"] returns error!"

      cached = @cacheCollection.find uid: uids.uid
      _uids = @uids.get()
      _.each cached.fetch(), (row) ->
        _uids = _.without _uids, row.optuid unless row.optuid is uids.optuid
      
      unless uids.isWrite
        _uids = _.union _uids, [ uids.optuid ]

      @uids.set _uids

      return @cache.get(uids.optuid, callback)

###
# @description Create Meteor.neo4j.uids ReactiveVar
###
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
      check val, String
      connectionURL = val
      if Meteor.isServer
        Meteor.neo4j.init()
    return
  configurable: false
  enumerable: false

@neo4j = Meteor.neo4j

if Meteor.isServer
  ###
  # @description Methods for reactive mini-neo4j
  ###
  Meteor.neo4j.___methods
    '___Neo4jObserveAdded': () ->
      return "MATCH (n#{@__labels} {_id: {_id}}) WITH count(n) AS count_n WHERE count_n <= 0 CREATE (n#{@__labels} {properties})"

    '___Neo4jObserveChanged': () ->
      return "MATCH (n#{@__labels} {_id: {_id}}) SET n = {properties}"

    '___Neo4jObserveRemoved': () ->
      return "MATCH (n#{@__labels} {_id: {_id}}) DELETE n"

  ###
  # @description Initialize connection to Neo4j
  ###
  Meteor.startup ->
    Meteor.neo4j.init() if not Meteor.neo4j.ready