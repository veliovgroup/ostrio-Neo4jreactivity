/*jshint strict:false */
/*global Meteor:false */
/*global Session:false */
/*global Neo4jCacheCollection:false */
/*global Tracker:false */

if (!this.neo4j) {
  this.neo4j = {};
}

if (!this.neo4j.uids) {
  if(Meteor.isClient){
    Session.setDefault('neo4juids', [null]);
  }

  this.neo4j.uids = (Meteor.isServer) ? [] : Session.get('neo4juids');
}

this.Neo4jCacheCollection = new Meteor.Collection('Neo4jCache');

if (Meteor.isServer) {
  Neo4jCacheCollection.allow({
    insert: function() {
      return false;
    },
    update: function() {
      return false;
    },
    remove: function() {
      return false;
    }
  });

  Meteor.publish('Neo4jCacheCollection', function(uids) {

    return Neo4jCacheCollection.find(
    {
      uid: {
        '$in': uids
      }
    });
  });
}

if (Meteor.isClient) {
  Tracker.autorun(function(){
    return Meteor.subscribe('Neo4jCacheCollection', Session.get('neo4juids'));
  });
}

