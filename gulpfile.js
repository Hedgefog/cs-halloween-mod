const gulp = require('gulp');
const watch = require('gulp-watch');
const sma = require('gulp-sma');
const flatten = require('gulp-flatten');

const config = require('./config');

const smaParams = {
    compiler: config.compiler.executable,
    dest: config.dest.pluginsDir,
    includeDir: config.project.includeDir
};

const reapiSmaParams = {
    compiler: config.compiler.executable,
    includeDir: [
        config.reapi.includeDir,
        config.project.includeDir
    ],
    dest: config.reapi.dest.pluginsDir
};

require('./tasks/build.task')('default', gulp, {sma: smaParams, dest: config.dest});
require('./tasks/watch.task')('watch', gulp, {sma: smaParams, dest: config.dest});

require('./tasks/build.task')('reapi', gulp, {sma: reapiSmaParams, dest: config.reapi.dest});
