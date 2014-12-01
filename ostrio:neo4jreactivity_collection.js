if (!this.neo4j) {
  this.neo4j = {};
}

if (!this.neo4j.uids) {
  this.neo4j.uids = (Meteor.isServer) ? [] : Session.set('neo4juids', []);
}

this.Neo4jCacheCollection = new Meteor.Collection('Neo4jCache');

if (Meteor.isServer) {
  Neo4jCacheCollection.allow({
    insert: function(userId, doc) {
      return doc.lastModified = doc.created = new Date();
    },
    update: function(userId, doc) {
      return false;
    },
    remove: function(userId, doc) {
      return false;
    }
  });

  Meteor.publish('Neo4jCacheCollection', function(uids) {

    return Neo4jCacheCollection.find(
    {
      uid: {
        '$in': uids
      },
      created: {
        $gte: new Date(new Date() - 24 * 60 * 60000)
      }
    });
  });
}

if (Meteor.isClient) {
  Tracker.autorun(function(){
    return Meteor.subscribe('Neo4jCacheCollection', Session.get('neo4juids'));
  });
}

