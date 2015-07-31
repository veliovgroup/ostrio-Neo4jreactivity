if Meteor.isServer
  Meteor.methods 
    Neo4jRun: (uid, query, opts, date) ->
      check uid, String
      check query, String
      check opts, Match.Optional Match.OneOf Object, null
      check date, Date
      
      if Meteor.neo4j.allowClientQuery == true
        return Meteor.neo4j.run(uid, query, opts, date)
      else
        throw new Meteor.Error '401', '[neo4j.query] method is not allowed on Client! : ' + [
          uid
          query
          opts
          date
        ].toString()