if (Meteor.isServer) {
  Meteor.methods({
    Neo4jRun: function(uid, query, opts, date) {
      if(neo4j.allowClientQuery === true){
        return neo4j.run(uid, query, opts, date);
      }else{
        throw new Meteor.Error('401', '[neo4j.query] method is not allowed on Client!', [uid, query, opts, date].toString());
      }
    }
  });
}