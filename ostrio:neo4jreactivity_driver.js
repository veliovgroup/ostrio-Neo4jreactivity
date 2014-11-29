var Fiber;

if (!this.neo4j) {
  this.neo4j = {};
}

neo4j.rules = {
  allow: ['RETURN', 'MATCH', 'SKIP', 'LIMIT', 'OPTIONAL', 'ORDER BY'],
  deny: ['CREATE', 'UNIQUE', 'MERGE', 'SET', 'DELETE', 'REMOVE', 'FOREACH', 'WHERE', 'ON', 'INDEX', 'USING', 'DROP']
};

neo4j.set = {
  allow: function(rules) {
    rules = this.apply(rules);
    neo4j.rules.allow = _.union(neo4j.rules.allow, rules);
    return neo4j.rules.deny = _.difference(neo4j.rules.deny, rules);
  },
  deny: function(rules) {
    rules = this.apply(rules);
    neo4j.rules.deny = _.union(neo4j.rules.deny, rules);
    return neo4j.rules.allow = _.difference(neo4j.rules.allow, rules);
  },
  apply: function(rules) {
    var key, val;
    for (key in rules) {
      val = rules[key];
      rules[key] = val.toUpperCase();
    }
    return rules;
  }
};

if (Meteor.isServer) {
  Fiber = Npm.require("fibers");
  this.N4JDB = new Neo4j();
  neo4j.run = function(uid, query, opts, date, callback) {
    neo4j.check(query);
    return N4JDB.query(query, opts, function(error, data) {
      return Fiber(function() {
        if (callback) {
          callback(error, data);
        }
        if (error) {
          throw new Meteor.Error('500', 'N4JDB.query: [neo4j.run]', [error, uid, query, opts, callback].toString());
          return null;
        } else {
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
        throw new Meteor.Error('500', 'Neo4jCacheCollection.insert: [neo4j.cache.put]', [error, uid, data].toString());
        return null;
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
  var uid;
  neo4j.check(query);
  uid = CryptoJS.SHA256(query).toString();
  if (Meteor.isServer) {
    neo4j.run(uid, query, opts, new Date(), callback);
  } else {
    Meteor.call('Neo4jRun', uid, query, opts, new Date(), callback, function(error) {
      if (error) {
        throw new Meteor.Error('500', 'Calling method [Neo4jRun]', [error, query, opts, callback].toString());
        return null;
      }
    });
  }
  return Neo4jCacheCollection.find({
    uid: uid
  });
};

neo4j.check = function(query) {
  return _.each(neo4j.rules.deny, function(value) {
    var _n;
    _n = new RegExp(value + ' ', "i");
    if (query.search(_n) !== -1) {
      throw new Meteor.Error('401', '[neo4j.check] "' + value + '" is not allowed!', query);
    }
  });
};