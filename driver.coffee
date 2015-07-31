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
      if _.isObject doc
        labels = if doc.__labels and doc.__labels.indexOf(':') is 0 then doc.__labels else ''
      else if _.isArray doc
        labelsArr = []
        _.each doc, (record) ->
          if _.has record, '__labels'
            labelsArr.push record.__labels
        labelsArr = _.uniq labelsArr
        labels = labels.join ''
      else
        labels = ''
      return labels

    if Meteor.isServer
      cursor.observe
        added: (doc) ->
          labels = getLabels doc
          if not Meteor.neo4j.collections[collectionName].isMapping
            delete doc.__labels if _.has doc, '__labels'
            delete doc.metadata if _.has doc, 'metadata'
            Meteor.neo4j.query "MATCH (n#{labels} {_id: {_id}}) WITH count(n) AS count_n WHERE count_n <= 0 CREATE (n#{labels} {properties})", {properties: doc, _id: doc._id}
          else
            Meteor.neo4j.collections[collectionName].isMapping = false
        changed: (doc, old) ->
          labels = getLabels doc
          if not Meteor.neo4j.collections[collectionName].isMapping
            delete doc.__labels if _.has doc, '__labels'
            delete doc.metadata if _.has doc, 'metadata'
            Meteor.neo4j.query "MATCH (n#{labels} {_id: {_id}}) SET n = {properties}", {_id: old._id, properties: doc}
          else
            Meteor.neo4j.collections[collectionName].isMapping = false
        removed: (doc) ->
          labels = getLabels doc
          if not Meteor.neo4j.collections[collectionName].isMapping
            delete doc.__labels if _.has doc, '__labels'
            delete doc.metadata if _.has doc, 'metadata'
            Meteor.neo4j.query "MATCH (n#{labels} {_id: {_id}}) DELETE n", {_id: doc._id}
          else
            Meteor.neo4j.collections[collectionName].isMapping = false
    else
      cursor.observe
        added: (doc) ->
          labels = getLabels doc
          if not Meteor.neo4j.collections[collectionName].isMapping
            delete doc.__labels if _.has doc, '__labels'
            delete doc.metadata if _.has doc, 'metadata'
            Meteor.neo4j.call '___Neo4jObserveAdded', {properties: doc, _id: doc._id, __labels: labels}, (error) ->
              return throw new Meteor.Error '500', '[___Neo4jObserveRemoved] | Error: ' + error.toString() if error
          else
            Meteor.neo4j.collections[collectionName].isMapping = false
        changed: (doc, old) ->
          labels = getLabels doc
          if not Meteor.neo4j.collections[collectionName].isMapping
            delete doc.__labels if _.has doc, '__labels'
            delete doc.metadata if _.has doc, 'metadata'
            Meteor.neo4j.call '___Neo4jObserveChanged', {_id: old._id, properties: doc, __labels: labels}, (error) ->
              return throw new Meteor.Error '500', '[___Neo4jObserveRemoved] | Error: ' + error.toString() if error
          else
            Meteor.neo4j.collections[collectionName].isMapping = false
        removed: (doc) ->
          labels = getLabels doc
          if not Meteor.neo4j.collections[collectionName].isMapping
            delete doc.__labels if _.has doc, '__labels'
            delete doc.metadata if _.has doc, 'metadata'
            Meteor.neo4j.call '___Neo4jObserveRemoved', {_id: doc._id, __labels: labels}, (error) ->
              return throw new Meteor.Error '500', '[___Neo4jObserveRemoved] | Error: ' + error.toString() if error
          else
            Meteor.neo4j.collections[collectionName].isMapping = false

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
    @subscriptions["#{collectionName}_#{name}"] = []
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

    self = @
    isReady = new ReactiveVar false
    throw new Meteor.Error '404', "[Meteor.neo4j.subscribe] | Collection: #{collectionName} not found! | Use Meteor.neo4j.collection(#{collectionName}) to create collection" if not Meteor.neo4j.collections[collectionName]

    @subscriptions["#{collectionName}_#{name}"] = []

    @call "Neo4jReactiveMethod_#{collectionName}_#{name}", opts, collectionName, link, (error, data) ->
      throw new Meteor.Error '500', '[Meteor.neo4j.subscribe] | Error: ' + error.toString() if error
      self.mapLink collectionName, data, link, "#{collectionName}_#{name}"
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

    self = @

    if link and data[link]
      if @subscriptions[subsName] and not _.isEmpty @subscriptions[subsName]
        oldIds = _.map @subscriptions[subsName], (doc) ->
          return doc._id

        newIds = _.map data[link], (doc) ->
          return doc._id

        diff = _.difference oldIds, newIds
        if diff and not _.isEmpty diff
          self.collections[collectionName].isMapping = true
          self.collections[collectionName].collection.remove
            _id: 
              $in: diff
          ,
           () ->
            self.collections[collectionName].isMapping = false

        self.subscriptions[subsName] = []

      _.each data[link], (doc) ->
        self.collections[collectionName].isMapping = true

        if not doc._id
          _id = Random.id()
        else
          _id = doc._id

        doc._id = _id

        self.subscriptions[subsName].push _.clone doc

        delete doc._id
        delete doc._data
        delete doc.data
        self.collections[collectionName].collection.upsert
          _id: _id
        , 
          $set: doc
        , 
         () ->
          self.collections[collectionName].isMapping = false

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
      _.each @rules.deny, (value) ->
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
    cached = Meteor.neo4j.cacheCollection.find uid: uid
    if cached.fetch().length == 0 or @isWrite(query)
      if Meteor.isServer
        @run uid, query, opts, new Date
      else if @allowClientQuery == true and Meteor.isClient
        Meteor.call 'Neo4jRun', uid, query, opts, new Date, (error) ->
          if error
            throw new Meteor.Error '500', 'Calling method [Neo4jRun]: ' + [
              error
              query
              opts
            ].toString()
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
    # @param uid {String} - Unique hashed ID of the query
    # @description Get cached response by UID
    # @returns object
    #
    ###
    getObject: (uid) ->
      check uid, String

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
      check uid, String
      check callback, Match.Optional Match.OneOf Function, null

      if Meteor.neo4j.allowClientQuery is true and Meteor.isClient
        if callback
          Tracker.autorun ->
            result = Meteor.neo4j.cacheCollection.findOne(uid: uid)
            if result and result.data
              callback and callback null, result.data
      else
        if callback
          if !Meteor.neo4j.cacheCollection.findOne(uid: uid)
            Meteor.neo4j.cacheCollection.find(uid: uid).observe 
              added: ->
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
      check uid, String
      check data, Match.Optional Match.OneOf [Object], null
      check queryString, String
      check opts, Match.Optional Match.OneOf Object, null
      check date, Date

      parsedData = Meteor.neo4j.parseReturn data, queryString
      Meteor.neo4j.cacheCollection.upsert
        uid: uid
      ,
        uid: uid
        data: parsedData
        query: queryString
        sensitivities: Meteor.neo4j.parseSensitivities queryString, opts, parsedData
        opts: opts
        type: if Meteor.neo4j.isWrite queryString then 'WRITE' else 'READ'
        created: date
      , 
        (error) ->
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
    check url, Match.Optional Match.OneOf String, null
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
      bound ->
        if Meteor.neo4j.isWrite query
          sensitivities = Meteor.neo4j.parseSensitivities query, opts

          if sensitivities
            affectedRecords = Meteor.neo4j.cacheCollection.find
              sensitivities: 
                '$in': sensitivities
              type: 'READ'

            affectedRecords.forEach (doc) ->
              Meteor.neo4j.run doc.uid, doc.query, doc.opts, doc.created
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
    check uid, String
    check query, String
    check opts, Match.Optional Match.OneOf Object, null
    check date, Date

    @check query
    Meteor.N4JDB.query query, opts, (error, data) ->
      bound ->
        if error
          throw new Meteor.Error '500', '[Meteor.neo4j.run]: ' + [
            error
            uid
            query
            opts
            date
          ].toString()
        else
          return Meteor.neo4j.cache.put uid, data or null, query, opts, date
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

    _data = data.map (result) ->
      _.each result, (value, key, list) ->
        if key.indexOf('.') != -1
          list[key.replace('.', '_')] = value
          delete list[key]
      result

    _res = undefined
    _originals = []
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

        _res = _res.map (str) ->
          str = str.trim()
          if str.indexOf(' AS ') != -1
            str = _.last str.split ' '
          str

        _clauses = _.last(_res)
        if _clauses.indexOf(' ') != -1
          _clause = _.first _clauses.split ' '
          _res[_res.length - 1] = _clause

        for i of _res
          _res[i] = _res[i].trim()
          _originals[i] = _res[i]
          if _res[i].indexOf(' ') != -1
            _res[i] = _.last _res[i].split ' '
            _originals[i] = _.first _res[i].split ' '
          _data[_res[i]] = []

        data.map (result) ->
          for i of _res
            if ! !result[_res[i]]
              if _res[i].indexOf('(') != -1 and _res[i].indexOf(')') != -1
                _data[_res[i]] = result[_res[i]]
              else if _originals[i].indexOf('.') != -1 or _.isString(result[_res[i]]) or _.isNumber(result[_res[i]]) or _.isBoolean(result[_res[i]]) or _.isDate(result[_res[i]]) or _.isNaN(result[_res[i]]) or _.isNull(result[_res[i]]) or _.isUndefined(result[_res[i]])
                _data[_res[i]].push result[_res[i]]
              else
                if !!result[_res[i]].data and ! !result[_res[i]]._data and ! !result[_res[i]]._data.metadata
                  result[_res[i]].data.metadata = result[_res[i]]._data.metadata

                if !!result[_res[i]]._data and ! !result[_res[i]]._data.start and ! !result[_res[i]]._data.end and ! !result[_res[i]]._data.type
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
    if parsedData and not _.isEmpty parsedData
      _.each parsedData, (set) ->
        if set and _.isObject set
          _.each set, (doc) ->
            if _.has doc, '_id'
              result.push doc._id

    _n = new RegExp(/"([a-zA-z0-9]*)"|'([a-zA-z0-9]*)'|:[^\'\"\ ](\w*)/gi)
    matches = undefined
    while matches = _n.exec query
      if matches[0]
        result.push matches[0].replace(/["']/gi, '')
    if opts
      _.each opts, (value) ->
        if _.isString value
          result.push value
    _.uniq result
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
        if collectionName
          self.query _query, opts, (error, data) ->
            throw new Meteor.Error '500', "[Meteor.neo4j.methods] | Error: " + error.toString() if error
            throw new Meteor.Error '404', "[Meteor.neo4j.methods] | Collection: #{collectionName} not found! | Use Meteor.neo4j.collection(#{collectionName}) to create collection" if not self.collections[collectionName]
            self.mapLink collectionName, data, link, _cmn

          self.onSubscribes[_cmn]() if self.onSubscribes[_cmn] and _.isFunction self.onSubscribes[_cmn]
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
  # @param name {String}         - Collection name
  # @param link {String}         - Sub object name, like 'user' for query: 
  #                                "MATCH (user {_id: '183091'}) RETURN user"
  # @description Call for server method registered via neo4j.methods() method, 
  #              returns error, data via callback.
  # @returns {Object} | With get() method [REACTIVE DATA SOURCE]
  #
  ###
  call: if Meteor.isClient then ((methodName, opts, name, link) ->
    check methodName, String
    check opts, Match.Optional Match.OneOf Object, null

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
  Meteor.neo4j.methods
    '___Neo4jObserveAdded': () ->
      return "MATCH (n#{@__labels} {_id: {_id}}) WITH count(n) AS count_n WHERE count_n <= 0 CREATE (n#{@__labels} {properties})"

    '___Neo4jObserveChanged': () ->
      return "MATCH (n#{@__labels} {_id: {_id}}) SET n = {properties}"

    '___Neo4jObserveRemoved': () ->
      return "MATCH (n#{@__labels} {_id: {_id}}) DELETE n"

  ###
  # @description Initialize connection to Neo4j
  ###
  Meteor.neo4j.init()