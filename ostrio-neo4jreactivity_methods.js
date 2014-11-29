if (Meteor.isServer) {
  Meteor.methods({
    Neo4jRun: function(uid, query, opts, date, callback) {
      return neo4j.run(uid, query, opts, date, callback);
    },
    Neo4jPut: function(uid, data) {
      return neo4j.cache.put(uid, data);
    },
    Neo4jGet: function(uid) {
      return neo4j.cache.get(uid);
    }
  });
}

