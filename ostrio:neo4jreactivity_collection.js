/*jshint strict:false */
/*global Meteor:false */
/*global Neo4jCacheCollection:false */
/*global Tracker:false */
/*global ReactiveVar:false */

/*
 *
 * @object
 * @name neo4j
 * @description Create application wide object `neo4j`
 *
 */
if (!this.neo4j) {
  Meteor.neo4j = {};
}

this.neo4j = Meteor.neo4j;

if (!Meteor.neo4j.uids) {
  if(Meteor.isClient){
    Meteor.neo4j.uids = new ReactiveVar([]);
  }

  Meteor.neo4j.uids = (Meteor.isServer) ? [] : Meteor.neo4j.uids.get();
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
    return Meteor.subscribe('Neo4jCacheCollection', Meteor.neo4j.uids.get());
  });
}

