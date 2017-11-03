const gulp = require('gulp');

require('./builder').initialize();

gulp.task('default', ['build']);