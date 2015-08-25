###
@object
@name neo4j
@description Create application wide object `neo4j`
###
Meteor.neo4j ?= {}

###
@object
@name neo4j
@property uids {[String]} - Array of strings
@description uids array od _id(s) from 'Neo4jCache' collection client needs to be subscribed
###
Meteor.neo4j.uids ?= new ReactiveVar []

###
@object
@name neo4j
@property cacheCollection {Object} - Meteor.Collection instance
@description Create reactive layer between Neo4j and Meteor
###
Meteor.neo4j.cacheCollection = new Meteor.Collection 'Neo4jCache'

if Meteor.isServer
  Meteor.neo4j.cacheCollection._ensureIndex
    uid: 1
    optuid: 1
  ,
    background: true
    sparse: true
    
  Meteor.neo4j.cacheCollection.allow
    insert: ->
      false
    update: ->
      false
    remove: ->
      false

  Meteor.publish 'Neo4jCacheCollection', (optuids) ->
    check optuids, Match.Optional Match.OneOf [String], null
    Meteor.neo4j.cacheCollection.find 
      optuid: 
        '$in': optuids

if Meteor.isClient
  Tracker.autorun ->
    Meteor.subscribe 'Neo4jCacheCollection', Meteor.neo4j.uids.get()