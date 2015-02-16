winston = require 'winston'
module.exports = 
    defaultLogger: new winston.Logger
        exitOnError: false
        transports: [
            new winston.transports.Console
                timestamp: true
                colorize: true
                prettyPrint: true
                level: 'debug'
            new winston.transports.File
                level: 'silly'
                filename: 'server.log'
        ]
