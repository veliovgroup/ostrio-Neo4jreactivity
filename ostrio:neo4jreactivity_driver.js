/*
 *
 * @object
 * @name neo4j
 * @description Create application wide object `neo4j`
 *
 */
if (!this.neo4j) {
  this.neo4j = {};
}

if (!this.neo4j.uids) {
  if(Meteor.isClient){
    Session.setDefault('neo4juids', [null]);
  }

  this.neo4j.uids = (Meteor.isServer) ? [] : Session.get('neo4juids');
}

/*
 *
 * @object
 * @namespace neo4j
 * @name rules
 * @property allow {array} - Array of allowed Cypher operators
 * @property deny {array} - Array of forbidden Cypher operators
 * @property write {array} - Array of write Cypher operators
 * @description Bunch of Cypher operators
 *
 */
neo4j.rules = {
  allow: ['RETURN', 'MATCH', 'SKIP', 'LIMIT', 'OPTIONAL', 'ORDER BY', 'WITH', 'AS', 'WHERE', 'CONSTRAINT'],
  deny: ['CREATE', 'UNIQUE', 'MERGE', 'SET', 'DELETE', 'REMOVE', 'FOREACH', 'ON', 'INDEX', 'USING', 'DROP'],
  write: ['CREATE', 'SET', 'DELETE', 'REMOVE', 'INDEX', 'DROP', 'MERGE']
};

/*
 *
 * @object
 * @namespace neo4j
 * @name set
 * @description Methods to set allow/deny operators
 *
 */
neo4j.set = {
  /*
   *
   * @function
   * @namespace neo4j.set
   * @name allow
   * @param rules {array} - Array of Cypher operators to be allowed in app
   *
   */
  allow: function(rules) {
    rules = this.apply(rules);
    this.rules.allow = _.union(this.rules.allow, rules);
    this.rules.deny = _.difference(this.rules.deny, rules);
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
    rules = this.apply(rules);
    this.rules.deny = _.union(this.rules.deny, rules);
    this.rules.allow = _.difference(this.rules.allow, rules);
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
};

if (Meteor.isServer) {

  var Fiber = Meteor.npmRequire("fibers");
  /*
   * @description Connect to neo4j database, returns GraphDatabase object
   */
  this.N4JDB = new Neo4j()

  /*
   *
   * @callback
   * @description Listen for all requests to neo4j
   * if request is writing/changing/removing data
   * we will find all sensitive data and update 
   * all subscribed records at Neo4jCacheCollection
   *
   */
  N4JDB.listen(function(query, opts){

    if(neo4j.isWrite(query)){

      var sensitivities = neo4j.parseSensitivities(query, opts);
      if(sensitivities){
        var affectedRecords = Neo4jCacheCollection.find({
          sensitivities:{
            '$in':sensitivities
          }, 
          type: 'READ'
        });

        Fiber(function() {
          affectedRecords.forEach(function(value){
            neo4j.run(value.uid, value.query, value.opts, value.created);
          });
        }).run();
      }
    }
  });

  /*
   *
   * @function
   * @namespace neo4j
   * @name run
   * @param uid {string} - Unique hashed ID of the query
   * @param query {string} - Cypher query
   * @param opts {object} - A map of parameters for the Cypher query
   * @param date {Date} - Creation date
   * @param callback {function} - Callback function(error, data) 
   * @description Run Cypher query, handle response with Fibers
   *
   */
  neo4j.run = function(uid, query, opts, date, callback) {

    this.check(query);

    N4JDB.query(query, opts, function(error, data) {

      Fiber(function() {
        if (callback) {
          callback(error, data);
        }
        if (error) {
          throw new Meteor.Error('500', 'N4JDB.query: [neo4j.run]', [error, uid, query, opts, callback].toString());
        } else {
          return neo4j.cache.put(uid, data || null, query, opts, date);
        }

      }).run();
    });
  };

  /*
   * @namespace neo4j.cache
   */
  if (!neo4j.cache) {
    neo4j.cache = {};
  }

  /*
   *
   * @function
   * @namespace neo4j.cache
   * @name put
   * @param uid {string} - Unique hashed ID of the query
   * @param data {object} - Data returned from neo4j (Cypher query response)
   * @param queryString {string} - Cypher query
   * @param opts {object} - A map of parameters for the Cypher query
   * @param date {Date} - Creation date
   * @description Upsert reactive mongo cache collection
   *
   */
  neo4j.cache.put = function(uid, data, queryString, opts, date) {

    return Neo4jCacheCollection.upsert({
      uid: uid
    }, {
      uid: uid,
      data: neo4j.parseReturn(data, queryString),
      query: queryString,
      sensitivities: neo4j.parseSensitivities(queryString, opts),
      opts: opts,
      type: (neo4j.isWrite(queryString)) ? 'WRITE' : 'READ',
      created: date
    }, function(error) {
      if (error) {
        throw new Meteor.Error('500', 'Neo4jCacheCollection.upsert: [neo4j.cache.put]', [error, uid, data].toString());
      }
    });
  };

  /*
   *
   * @function
   * @namespace neo4j.cache
   * @name get
   * @param uid {string} - Unique hashed ID of the query
   * @description Get cached response by UID
   * @returns Mongo.cursor
   *
   */
  neo4j.cache.get = function(uid) {
    return Neo4jCacheCollection.find({
      uid: uid
    });
  };
}

/*
 *
 * @function
 * @namespace neo4j
 * @name query
 * @param query {string} - Cypher query
 * @param opts {object} - A map of parameters for the Cypher query
 * @param callback {function} - Callback function(error, data) 
 * @description Isomorphic Cypher query call
 * @returns Mongo.cursor [REACTIVE DATA SOURSE]
 *
 */
neo4j.query = function(query, opts, callback) {

  this.queryString = query;
  this.check(query);
  var uid = CryptoJS.SHA256(query).toString();
  Session.set('neo4juids', _.union(Session.get('neo4juids'), [uid]));

  var cached = Neo4jCacheCollection.find({
    uid: uid
  });

  if(cached.fetch().length === 0){
    if (Meteor.isServer) {
      this.run(uid, query, opts, new Date(), callback);
    } else {
      Meteor.call('Neo4jRun', uid, query, opts, new Date(), callback, function(error) {
        if (error) {
          throw new Meteor.Error('500', 'Calling method [Neo4jRun]', [error, query, opts, callback].toString());
        }
      });
    }
  }

  return Neo4jCacheCollection.find({
    uid: uid
  });
};

/*
 *
 * @function
 * @namespace neo4j
 * @name search
 * @param regexp {RegExp} - Regular Expression
 * @param string {string} - Haystack
 * @param callback {function} - (OPTIONAL) Callback function(error, data) 
 * @description do search by RegExp in string
 * @returns {boolean}
 *
 */
neo4j.search = function(regexp, string, callback){
  if (string && string.search(regexp) !== -1) {
    return (callback) ? callback(true) : true;
  }else{
    return (callback) ? callback(false) : false;
  }
};

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
neo4j.check = function(query) {
  var _n;
  _.each(this.rules.deny, function(value) {
    _n = new RegExp(value + ' ', "i");
    neo4j.search(_n, query, function(isFound){
      if (isFound) throw new Meteor.Error('401', '[neo4j.check] "' + value + '" is not allowed!', query);
    });
  });
};

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
neo4j.parseReturn = function(data, queryString){
  var i,
      _res,
      _data = data,
      _n = new RegExp('return ', "i");

  var wait = this.search(_n, queryString, function(isFound){
    if(isFound){
      _data = {},
      _originals = [];
      _res = queryString.replace(/.*return /i,"").trim();
      _res = _res.split(',');

      for (i in _res){
        _res[i] = _res[i].trim();
        _originals[i] = _res[i];


        if(_res[i].indexOf(" ") !== -1){
          _res[i] = _.last(_res[i].split(' '));
          _originals[i] = _.first(_res[i].split(' '));
        }

        _data[_res[i]] = [];
      }

      data.map(function (result) {
        for (i in _res){
          if(!!result[_res[i]]){
            if (_originals[i].indexOf(".") !== -1) {
              _data[_res[i]].push(result[_res[i]]);
            }else{
              if(!!result[_res[i]].data && !!result[_res[i]]._data && !!result[_res[i]]._data.metadata)
                result[_res[i]].data.metadata = result[_res[i]]._data.metadata

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

  neo4j.returns = _res;
  return _data;
};

/*
 *
 * @function
 * @namespace neo4j
 * @name parseSensitivities
 * @param query {string} - Cypher query
 * @param opts {object} - A map of parameters for the Cypher query.
 * @description Parse Cypher query for sensitive data
 * @returns {Array}
 *
 */
neo4j.parseSensitivities = function(query, opts){
  var _n = new RegExp(/"([a-zA-z0-9]*)"|'([a-zA-z0-9]*)'/gi);
  var matches, result = [];
  while(matches = _n.exec(query)){ 
    if(matches[0]){
      result.push(matches[0].replace(/["']/gi, ""));
    }
  }

  if(opts){
    result = _.union(_.values(opts), result);
  }

  return result;
};

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
neo4j.isWrite = function(query){
  var _n = new RegExp("(" + neo4j.rules.write.join('|') + "*)", "gi");
  return neo4j.search(_n, query)
};


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
neo4j.isRead = function(query){
  var _n = new RegExp("(" + neo4j.rules.write.join('|') + "*)", "gi");
  return !neo4j.search(_n, query)
};