const sma = require('gulp-sma');
const flatten = require('gulp-flatten');
const watch = require('gulp-watch');

module.exports = (name, gulp, options) => {
    gulp.task(`plugins:${name}`, () => {
        return watch('./src/scripts/**/*.sma', {ignoreInitial: false})
            .pipe(sma(options.sma))
            .pipe(flatten())
            .pipe(gulp.dest(options.dest.scriptsDir));
    });
    
    gulp.task(`include:${name}`, () => {
        return watch('./src/include/*.inc', {ignoreInitial: false})
            .pipe(gulp.dest(options.dest.includeDir));
    });
    
    gulp.task(`assets:${name}`, () => {
        return watch('./assets/**/*', {ignoreInitial: false})
            .pipe(gulp.dest(options.dest.dir));
    });

    gulp.task(name, [`plugins:${name}`, `include:${name}`, `assets:${name}`]);
};
