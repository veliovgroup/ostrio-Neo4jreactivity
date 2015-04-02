/*jshint strict:false */
/*global Meteor:false */
/*global _:false */
/*global Tracker:false */
/*global Package:false */
/*global ReactiveVar:false */
/*global Neo4jCacheCollection:false */

if (Meteor.isServer) {
  var bound = Meteor.bindEnvironment(function(callback){
    callback();
  });
  Meteor.N4JDB = {};
  this.N4JDB = Meteor.N4JDB;
}

/*
 *
 * @object
 * @namespace Meteor
 * @name neo4j
 * @description Create `neo4j` object
 *
 */
Meteor.neo4j = {

  resultsCache: {},

  /*
   *
   * @property allowClientQuery {boolean}
   * @description Set to true to allow run queries from client
   *              Please, do not forget about security and 
   *              at least run Meteor.neo4j.set.deny(Meteor.neo4j.rules.write)
   *
   */
  allowClientQuery: false,

  /*
   *
   * @function
   * @namespace neo4j
   * @name search
   * @param regexp {RegExp}     - Regular Expression
   * @param string {string}     - Haystack
   * @param callback {function} - (OPTIONAL) Callback function(error, data) 
   * @description do search by RegExp in string
   * @returns {boolean}
   *
   */
  search: function(regexp, string, callback){
    if (string && string.search(regexp) !== -1) {
      return (callback) ? callback(true) : true;
    }else{
      return (callback) ? callback(false) : false;
    }
  },

  /*
   *
   * @function
   * @namespace neo4j
   * @name check
   * @param query {string} - Cypher query
   * @description Check query for forbidden operators
   * @returns {undefined} or {throw new Meteor.Error(...)}
   *
   */
  check: function(query) {
    if(Meteor.isClient){
      var _n;
      _.forEach(this.rules.deny, function(value) {
        _n = new RegExp(value + ' ', 'i');
        Meteor.neo4j.search(_n, query, function(isFound){
          if (isFound) throw new Meteor.Error('401', '[Meteor.neo4j.check] "' + value + '" is not allowed! | ' + [query].toString());
        });
      });
    }
  },

  /*
   *
   * @object
   * @namespace neo4j
   * @name rules
   * @property allow {array}  - Array of allowed Cypher operators
   * @property deny {array}   - Array of forbidden Cypher operators
   * @property write {array}  - Array of write Cypher operators
   * @description Bunch of Cypher operators
   *
   */
  rules: {
    allow: ['RETURN', 'MATCH', 'SKIP', 'LIMIT', 'OPTIONAL', 'ORDER BY', 'WITH', 'AS', 'WHERE', 'CONSTRAINT', 'UNWIND', 'DISTINCT', 'CASE', 'WHEN', 'THEN', 'ELSE', 'END', 'CREATE', 'UNIQUE', 'MERGE', 'SET', 'DELETE', 'REMOVE', 'FOREACH', 'ON', 'INDEX', 'USING', 'DROP'],
    deny: [],
    write: ['CREATE', 'SET', 'DELETE', 'REMOVE', 'INDEX', 'DROP', 'MERGE']
  },

  /*
   *
   * @object
   * @namespace neo4j
   * @name set
   * @description Methods to set allow/deny operators
   *
   */
  set: {
    /*
     *
     * @function
     * @namespace neo4j.set
     * @name allow
     * @param rules {array} - Array of Cypher operators to be allowed in app
     *
     */
    allow: function(rules) {
      if(rules === '*'){
        Meteor.neo4j.rules.allow = _.union(Meteor.neo4j.rules.allow, Meteor.neo4j.rules.deny);
        Meteor.neo4j.rules.deny = [];
      }else{
        rules = this.apply(rules);
        Meteor.neo4j.rules.allow = _.union(Meteor.neo4j.rules.allow, rules);
        Meteor.neo4j.rules.deny = _.difference(Meteor.neo4j.rules.deny, rules);
      }
    },

    /*
     *
     * @function
     * @namespace neo4j.set
     * @name deny
     * @param rules {array} - Array of Cypher operators to be forbidden in app
     *
     */
    deny: function(rules) {
      if(rules === '*'){
        Meteor.neo4j.rules.deny = _.union(Meteor.neo4j.rules.allow, Meteor.neo4j.rules.deny);
        Meteor.neo4j.rules.allow = [];
      }else{
        rules = this.apply(rules);
        Meteor.neo4j.rules.deny = _.union(Meteor.neo4j.rules.deny, rules);
        Meteor.neo4j.rules.allow = _.difference(Meteor.neo4j.rules.allow, rules);
      }
    },

    /*
     *
     * @function
     * @namespace neo4j.set
     * @name apply
     * @param rules {array} - fix lowercased operators
     *
     */
    apply: function(rules) {
      var key;
      for (key in rules) {
        rules[key] = rules[key].toUpperCase();
      }
      return rules;
    }
  },

  /*
   *
   * @function
   * @namespace neo4j
   * @name mapParameters
   * @param query {string}      - Cypher query
   * @param opts {object}       - A map of parameters for the Cypher query
   * 
   * @description Isomorphic mapParameters for Neo4j query
   * @returns {string} - query with replaced map of parameters
   *
   */
  mapParameters: function(query, opts){
    _.forEach(opts, function(value, key){
      value = (!isNaN(value)) ? value : '"' + value + '"';
      query = query.replace('{' + key + '}', value).replace('{ ' + key + ' }', value);
    });
    return query;
  },

  /*
   *
   * @function
   * @namespace neo4j
   * @name query
   * @param query {string}      - Cypher query
   * @param opts {object}       - A map of parameters for the Cypher query
   * @param callback {function} - Callback function(error, data){...}
   * @description Isomorphic Cypher query call
   * @returns {object} | With get() method [REACTIVE DATA SOURCE]
   *
   */
  query: function(query, opts, callback) {
    if(opts){
      query = this.mapParameters(query, opts);
      opts = null;
    }

    this.check(query);
    var uid = Package.sha.SHA256(query);
    
    var cached = Neo4jCacheCollection.find({
      uid: uid
    });

    if(cached.fetch().length === 0 || this.isWrite(query)){
      if(Meteor.isServer){
        this.run(uid, query, opts, new Date());
      }else if(this.allowClientQuery === true && Meteor.isClient){
        Meteor.call('Neo4jRun', uid, query, opts, new Date(), function(error) {
          if (error) {
            throw new Meteor.Error('500', 'Calling method [Neo4jRun]: ' + [error, query, opts].toString());
          }
        });
        Meteor.neo4j.uids.set(_.union(Meteor.neo4j.uids.get(), [uid]));
      }
    }

    return this.cache.get(uid, callback);
  },


  /*
   *
   * @function
   * @namespace neo4j
   * @name isWrite
   * @param query {string} - Cypher query
   * @description Returns true if `query` writing/changing/removing data
   * @returns {boolean}
   *
   */
  isWrite: function(query){
    var _n = new RegExp('(' + this.rules.write.join('|') + '*)', 'gi');
    return this.search(_n, query);
  },

  /*
   *
   * @function
   * @namespace neo4j
   * @name isRead
   * @param query {string} - Cypher query
   * @description Returns true if `query` only reading
   * @returns {boolean}
   *
   */
  isRead: function(query){
    var _n = new RegExp('(' + this.rules.write.join('|') + '*)', 'gi');
    return !this.search(_n, query);
  },

  cache: {
    /*
     *
     * @function
     * @namespace neo4j.cache
     * @name getObject
     * @param uid {string}      - Unique hashed ID of the query
     * @description Get cached response by UID
     * @returns object
     *
     */
    getObject: function(uid) {
      if(Meteor.neo4j.allowClientQuery === true && Meteor.isClient || Meteor.isServer){
        var cache = Neo4jCacheCollection.find({uid: uid});

        if(Meteor.isServer){
          if(Neo4jCacheCollection.findOne({uid: uid})){
            Meteor.neo4j.resultsCache['NEO4JRES_' + uid] = Neo4jCacheCollection.findOne({uid: uid}).data;
          }


          cache.observe({
            added: function(doc){
              Meteor.neo4j.resultsCache['NEO4JRES_' + uid] = doc.data;
            },
            changed: function(doc){
              Meteor.neo4j.resultsCache['NEO4JRES_' + uid] = doc.data;
            },
            removed: function(){
              Meteor.neo4j.resultsCache['NEO4JRES_' + uid] = null;
            }
          });

          return {
            cursor: cache,
            get: function(){
              return Meteor.neo4j.resultsCache['NEO4JRES_' + uid];
            }
          };

        }else{

          var result = new ReactiveVar(null);

          if(Neo4jCacheCollection.findOne({uid: uid})){
            result.set(Neo4jCacheCollection.findOne({uid: uid}).data);
          }

          cache.observe({
            added: function(doc){
              result.set(doc.data);
            },
            changed: function(doc){
              result.set(doc.data);
            },
            removed: function(){
              result.set(null);
            }
          });

          return {
            cursor: cache,
            get: function(){
              return result.get();
            }
          };
        }
      }
    },

    /*
     *
     * @function
     * @namespace neo4j.cache
     * @name get
     * @param uid {string}      - Unique hashed ID of the query
     * @param callback {function}   - Callback function(error, data){...}.
     * @description Get cached response by UID
     * @returns object
     *
     */
    get: function(uid, callback) {

      if(Meteor.neo4j.allowClientQuery === true && Meteor.isClient){
        
        if(callback){
          Tracker.autorun(function(){
            var result = Neo4jCacheCollection.findOne({uid: uid});
            if(result && result.data){
              callback(null, result.data);
            }
          });
        }

      }else{

        if(callback){
          if(!Neo4jCacheCollection.findOne({uid: uid})){
            Neo4jCacheCollection.find({uid: uid}).observe({
              added: function(){
                callback(null, Neo4jCacheCollection.findOne({uid: uid}).data);
              }
            });
          }else{
            callback(null, Neo4jCacheCollection.findOne({uid: uid}).data);
          }
        }
      }

      return Meteor.neo4j.cache.getObject(uid);
    },


    /*
     *
     * @function
     * @namespace neo4j.cache
     * @name put
     * @param uid {string}          - Unique hashed ID of the query
     * @param data {object}         - Data returned from neo4j (Cypher query response)
     * @param queryString {string}  - Cypher query
     * @param opts {object}         - A map of parameters for the Cypher query
     * @param date {Date}           - Creation date
     * @description Upsert reactive mongo cache collection
     *
     */
    put: (Meteor.isServer) ? function(uid, data, queryString, opts, date) {
      return Neo4jCacheCollection.upsert({
        uid: uid
      }, {
        uid: uid,
        data: Meteor.neo4j.parseReturn(data, queryString),
        query: queryString,
        sensitivities: Meteor.neo4j.parseSensitivities(queryString, opts),
        opts: opts,
        type: (Meteor.neo4j.isWrite(queryString)) ? 'WRITE' : 'READ',
        created: date
      }, function(error) {
        if (error) {
          throw new Meteor.Error('500', 'Neo4jCacheCollection.upsert: [Meteor.neo4j.cache.put]: ' + [error, uid, data, queryString, opts, date].toString());
        }
      });
    } : undefined
  },

  init: (Meteor.isServer) ? function(url){
    if(url && this.connectionURL == null){
      this.connectionURL = url;
    }

    /*
     * @description Connect to Neo4j database, returns GraphDatabase object
     */
    Meteor.N4JDB = new Meteor.Neo4j(Meteor.neo4j.connectionURL);

    /*
     *
     * @callback
     * @description Listen for all requests to Neo4j
     * if request is writing/changing/removing data
     * we will find all sensitive data and update 
     * all subscribed records at Neo4jCacheCollection
     *
     */
    Meteor.N4JDB.listen(function(query, opts){
      if(Meteor.neo4j.isWrite(query)){
        var sensitivities = Meteor.neo4j.parseSensitivities(query, opts);
        if(sensitivities){
          var affectedRecords = Neo4jCacheCollection.find({
            sensitivities:{
              '$in':sensitivities
            }, 
            type: 'READ'
          });

          bound(function() {
            affectedRecords.forEach(function(value){
              Meteor.neo4j.run(value.uid, value.query, value.opts, value.created);
            });
          });
        }
      }
    });
  } : undefined,

  /*
   *
   * @function
   * @namespace neo4j
   * @name run
   * @param uid {string}        - Unique hashed ID of the query
   * @param query {string}      - Cypher query
   * @param opts {object}       - A map of parameters for the Cypher query
   * @param date {Date}         - Creation date
   * @description Run Cypher query, handle response with Fibers
   *
   */
  run: (Meteor.isServer) ? function(uid, query, opts, date) {
    this.check(query);

    Meteor.N4JDB.query(query, opts, function(error, data) {
      bound(function() {
        if (error) {
          throw new Meteor.Error('500', 'Meteor.N4JDB.query: [Meteor.neo4j.run]: ' + [error, uid, query, opts, date].toString());
        } else {
          return Meteor.neo4j.cache.put(uid, data || null, query, opts, date);
        }
      });
    });
  } : undefined,


  /*
   *
   * @function
   * @namespace neo4j
   * @name parseReturn
   * @param data {object} - Cypher query response, neo4j database response
   * @description Parse returned object from neo4j
   * @returns {object}
   *
   */
  parseReturn: (Meteor.isServer) ? function(data, queryString){
    data = data.map(function (result){
      _.each(result, function(value, key, list){
        if(key.indexOf('.') !== -1){
          list[key.replace('.', '_')] = value;
          delete list[key];
        }
      });
      return result;
    });

    var _res,
        _data = data,
        _originals = [],
        _clauses,
        wait,
        _n = new RegExp('return ', 'i');

    wait = this.search(_n, queryString, function(isFound){
      if(isFound){
        _data = {};
        _res = queryString.replace(/.*return /i,'').trim();
        _res = _res.split(',');

        for (var i = _res.length - 1; i >= 0; i--) {
          if(_res[i].indexOf('.') !== -1){
            _res[i] = _res[i].replace('.', '_');
          }
        }

        _res = _res.map(function(str){ 
          str = str.trim(); 
          if(str.indexOf(' AS ') !== -1){
            str = _.last(str.split(' '));
          }
          return str;
        });

        _clauses = _.last(_res);
        if(_clauses.indexOf(' ') !== -1){
          var _clause = _.first(_clauses.split(' '));
          _res[_res.length - 1] = _clause;
        }

        for (i in _res){
          _res[i] = _res[i].trim();
          _originals[i] = _res[i];

          if(_res[i].indexOf(' ') !== -1){
            _res[i] = _.last(_res[i].split(' '));
            _originals[i] = _.first(_res[i].split(' '));
          }

          _data[_res[i]] = [];
        }

        data.map(function (result) {
          for (i in _res){
            if(!!result[_res[i]]){
              if(_res[i].indexOf('(') !== -1 && _res[i].indexOf(')') !== -1){
                _data[_res[i]] = result[_res[i]];
              }else if (_originals[i].indexOf('.') !== -1 || _.isString(result[_res[i]]) || _.isNumber(result[_res[i]]) || _.isBoolean(result[_res[i]]) || _.isDate(result[_res[i]]) || _.isNaN(result[_res[i]]) || _.isNull(result[_res[i]]) || _.isUndefined(result[_res[i]])) {
                _data[_res[i]].push(result[_res[i]]);
              }else{
                if(!!result[_res[i]].data && !!result[_res[i]]._data && !!result[_res[i]]._data.metadata)
                  result[_res[i]].data.metadata = result[_res[i]]._data.metadata;

                if(!!result[_res[i]]._data && !!result[_res[i]]._data.start && !!result[_res[i]]._data.end && !!result[_res[i]]._data.type)
                  
                  result[_res[i]].data.relation = {
                    extensions  : result[_res[i]]._data.extensions,
                    start : _.last(result[_res[i]]._data.start.split('/')),
                    end   : _.last(result[_res[i]]._data.end.split('/')),
                    self  : _.last(result[_res[i]]._data.self.split('/')),
                    type  : result[_res[i]]._data.type
                  };

                if(!!result[_res[i]].data)
                  _data[_res[i]].push(result[_res[i]].data);
              }
            }
          }
        });
      }
    });

    this.returns = _res;
    return _data;
  } : undefined,


  /*
   *
   * @function
   * @namespace neo4j
   * @name parseSensitivities
   * @param query {string}  - Cypher query
   * @param opts {object}   - A map of parameters for the Cypher query.
   * @description Parse Cypher query for sensitive data
   * @returns {Array}
   *
   */
  parseSensitivities: (Meteor.isServer) ? function(query, opts){
    var _n = new RegExp(/"([a-zA-z0-9]*)"|'([a-zA-z0-9]*)'|:[^\'\"\ ](\w*)/gi);
    var matches, result = [];
    while(matches = _n.exec(query)){ 
      if(matches[0]){
        result.push(matches[0].replace(/["']/gi, ''));
      }
    }

    if(opts){
      _.forEach(opts, function(value, key){
        result.push(value);
        result.push(key);
      });
    }

    return result;
  } : undefined,

  /*
   *
   * @function
   * @namespace neo4j
   * @name methods
   * @param methods {object} - Object of methods, like: 
   *                           {
   *                              methodName: function(){ 
   *                                return 'MATCH (a:User {name: {userName}}) RETURN a';
   *                              } 
   *                           }
   * @description Create server methods to send query to neo4j database
   * @returns {string} record uid
   *
   */
  methods: (Meteor.isServer) ? function(methods){
    var _methods = {};

    _.forEach(methods, function(query, methodName){
      _methods[methodName] = function(opts){
        var _query = query();
        if(opts){
          _query = Meteor.neo4j.mapParameters(_query, opts);
          opts = null;
        }
        var uid = Package.sha.SHA256(_query);
        Meteor.neo4j.query(_query, opts);
        return uid;
      };
    });
    Meteor.methods(_methods);
  } : undefined,

  /*
   *
   * @function
   * @namespace neo4j
   * @name call
   * @param methodName {string}   - method name registered via neo4j.methods() method
   * @param opts {object|null}    - [NOT REQUIRED] A map of parameters for the Cypher query. 
   *                                Like: {userName: 'Joe'}, for query like: MATCH (a:User {name: {userName}}) RETURN a
   * @param callback {function}   - Callback function(error, data){...}.
   * @description Call for server method registered via neo4j.methods() method, 
   *              returns error, data via callback.
   * @returns {object} | With get() method [REACTIVE DATA SOURCE]
   *
   */
  call: (Meteor.isClient) ? function(methodName, opts, callback){
    Meteor.call(methodName, opts, function(error, uid){
      if(error){
        throw new Meteor.Error('500', '[Meteor.neo4j.call] Method: ["' + methodName + '"] returns error! | ' + [error].toString());
      }else{
        Meteor.neo4j.uids.set(_.union(Meteor.neo4j.uids.get(), [uid]));
        return Meteor.neo4j.cache.get(uid, callback);
      }
    });
    return undefined;
  } : undefined
};

/*
 *
 * @description Create Meteor.neo4j.uids ReactiveVar
 *
 */
if(Meteor.isClient){
  Meteor.neo4j.uids = new ReactiveVar([]);
}

/*
 *
 * @property connectionURL {string} - url to Neo4j database
 * @description Set connection URL to Neo4j Database
 *
 */
var connectionURL = null;

Object.defineProperty(Meteor.neo4j, 'connectionURL',{
  get: function () {
    return connectionURL;
  },

  set: function (val) {
    if(val !== connectionURL){
      connectionURL = val;

      if(Meteor.isServer){
        Meteor.neo4j.init();
      }
    }
  },

  configurable: false,
  enumerable: false
});

this.neo4j = Meteor.neo4j;

if (Meteor.isServer) {

  /*
   *
   * @description Initialize connection to Neo4j
   *
   */
  Meteor.neo4j.init();
}