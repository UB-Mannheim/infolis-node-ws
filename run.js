#!env node
var sys = require('sys');
var spawn = require('child_process').spawn;
var minimist = require('minimist');
var augmentedEnv = JSON.parse(JSON.stringify(process.env));
augmentedEnv.NODE_PATH = 'lib';

var usage = function() {
    console.log("Usage:");
    console.log(process.argv[0] + " " + process.argv[1] + " debug");
};

var main = function() {
    var args = minimist(process.argv.slice(2));
    var action = args._[0];

    if (action === 'debug') {
        console.log("Starting server via nodemon");
        spawn('nodemon',  
              'server.coffee'.split(/ /),
              {
                  env: augmentedEnv,
                  stdio: "inherit"
              });
    } else {
        usage();
    }
}();
