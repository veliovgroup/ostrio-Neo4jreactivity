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

  Meteor.publish('Neo4jCacheCollection', function() {
    return Neo4jCacheCollection.find({
      created: {
        $gte: new Date(new Date() - 24 * 60 * 60000)
      }
    });
  });
}

if (Meteor.isClient) {
  Meteor.subscribe('Neo4jCacheCollection');
}

