Package.describe({
  name: 'ostrio:neo4jreactivity',
  summary: 'Meteor.js Neo4j database reactivity layer',
  version: '0.9.0',
  git: 'https://github.com/VeliovGroup/ostrio-Neo4jreactivity.git'
});

Package.onUse(function(api) {
  api.versionsFrom('1.0');
  api.addFiles(['driver.coffee', 'collection.coffee'], ['client', 'server']);
  api.addFiles('methods.coffee', 'server');
  api.use(['mongo', 'check', 'underscore', 'sha', 'coffeescript', 'random', 'ostrio:minimongo-extensions@1.0.1'], ['client', 'server']);
  api.use(['tracker', 'reactive-var'], 'client');
  api.use('ostrio:neo4jdriver@0.2.15', 'server');
  api.imply('ostrio:neo4jdriver@0.2.15');
});

Npm.depends({
  neo4j: '1.1.1'
});