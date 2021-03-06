#!/usr/bin/env node
var program = require('commander')

program
  .version('0.0.1')
  .command('pull-assessments <url>', 'install one or more packages')
  .command('pull-workflows <url>', 'install one or more packages')
  .command('push-backup <url>', 'search with optional query')
  .command('deploy-globals <url>', 'search with optional query')
  .parse(process.argv);
