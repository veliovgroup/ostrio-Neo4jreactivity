Package.describe({
  name: 'ostrio:neo4jreactivity',
  summary: 'Meteor.js Neo4j database reactivity layer',
  version: '0.5.5',
  git: 'https://github.com/VeliovGroup/ostrio-Neo4jreactivity.git'
});

Package.onUse(function(api) {
  api.versionsFrom('1.0');
  api.addFiles(['ostrio:neo4jreactivity_driver.js', 'ostrio:neo4jreactivity_collection.js', 'ostrio:neo4jreactivity_methods.js']);
  api.use(['underscore', 'sha'], ['client', 'server']);
  api.use(['tracker', 'session', 'reactive-var'], 'client');
  api.use('ostrio:neo4jdriver@0.2.11');
});

Npm.depends({
  neo4j: '1.1.1'
});