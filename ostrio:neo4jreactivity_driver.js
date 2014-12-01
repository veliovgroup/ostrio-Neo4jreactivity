if (!this.neo4j) {
  this.neo4j = {};
}

neo4j.rules = {
  allow: ['RETURN', 'MATCH', 'SKIP', 'LIMIT', 'OPTIONAL', 'ORDER BY', 'WITH', 'AS', 'WHERE'],
  deny: ['CREATE', 'UNIQUE', 'MERGE', 'SET', 'DELETE', 'REMOVE', 'FOREACH', 'ON', 'INDEX', 'USING', 'DROP']
};

neo4j.set = {
  allow: function(rules) {
    rules = this.apply(rules);
    this.rules.allow = _.union(this.rules.allow, rules);
    this.rules.deny = _.difference(this.rules.deny, rules);
  },
  deny: function(rules) {
    rules = this.apply(rules);
    this.rules.deny = _.union(this.rules.deny, rules);
    this.rules.allow = _.difference(this.rules.allow, rules);
  },
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
  this.N4JDB = new Neo4j();

  neo4j.run = function(uid, query, opts, date, callback) {

    this.queryString = query;
    this.check(query);

    N4JDB.query(query, opts, function(error, data) {
      Fiber(function() {
        if (callback) {
          callback(error, data);
        }

        if (error) {
          throw new Meteor.Error('500', 'N4JDB.query: [neo4j.run]', [error, uid, query, opts, callback].toString());
        } else {
          data = neo4j.parseReturn(data);
          return neo4j.cache.put(uid, data || null, date);
        }

      }).run();
    });
  };
  
  if (!neo4j.cache) {
    neo4j.cache = {};
  }

  neo4j.cache.put = function(uid, data, date) {
    return Neo4jCacheCollection.upsert({
      uid: uid
    }, {
      uid: uid,
      data: data,
      created: date
    }, function(error) {
      if (error) {
        throw new Meteor.Error('500', 'Neo4jCacheCollection.upsert: [neo4j.cache.put]', [error, uid, data].toString());
      }
    });
  };

  neo4j.cache.get = function(uid) {
    return Neo4jCacheCollection.find({
      uid: uid
    });
  };
}

neo4j.query = function(query, opts, callback) {
  this.queryString = query;
  var uid;
  this.check(query);
  uid = CryptoJS.SHA256(query).toString();

  var cached = Neo4jCacheCollection.findOne({
    uid: uid
  });

  if(!cached){
    if (Meteor.isServer) {
      this.run(uid, query, opts, new Date(), callback);
    } else {
      Meteor.call('Neo4jRun', uid, query, opts, new Date(), callback, function(error) {
        if (error) {
          throw new Meteor.Error('500', 'Calling method [Neo4jRun]', [error, query, opts, callback].toString());
          return null;
        }
      });
    }
  }

  return Neo4jCacheCollection.find({
    uid: uid
  });
};

neo4j.search = function(regexp, string, callback){
  if (string && string.search(regexp) !== -1) {
    return callback(true);
  }else{
    return callback(false);
  }
};

neo4j.check = function(query) {
  var _n;
  _.each(this.rules.deny, function(value) {
    _n = new RegExp(value + ' ', "i");
    neo4j.search(_n, query, function(isFound){
      if (isFound) throw new Meteor.Error('401', '[neo4j.check] "' + value + '" is not allowed!', query);
    });
  });
};

neo4j.parseReturn = function(data){
  var i,
      _res,
      _data = data,
      _n = new RegExp('return ', "i");

  var wait = this.search(_n, this.queryString, function(isFound){
    if(isFound){
      _data = {},
      _originals = [];
      _res = neo4j.queryString.replace(/.*return /i,"").trim();
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
      });
    }
  });

  neo4j.returns = _res;
  return _data;
};