if (Meteor.isServer) {
  Meteor.methods({
    Neo4jRun: function(uid, query, opts, date, callback) {
      return neo4j.run(uid, query, opts, date, callback);
    }
  });
}

