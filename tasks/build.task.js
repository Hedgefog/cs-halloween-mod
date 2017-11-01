const sma = require('gulp-sma');
const flatten = require('gulp-flatten');

function resolveTaskName(task, name) {
    return `${task}:${name}`;
}

module.exports = (name, gulp, options) => {
    gulp.task(resolveTaskName(name, 'plugins'), () => {
        return gulp.src('./src/scripts/**/*.sma')
            .pipe(sma(options.sma))
            .pipe(flatten())
            .pipe(gulp.dest(options.dest.scriptsDir));
    });
    
    gulp.task(resolveTaskName(name, 'include'), () => {
        return gulp.src('./src/include/*.inc')
            .pipe(gulp.dest(options.dest.includeDir));
    });
    
    gulp.task(resolveTaskName(name, 'assets'), () => {
        return gulp.src('./assets/**/*')
            .pipe(gulp.dest(options.dest.dir));
    });

    gulp.task(name, [
        resolveTaskName(name, 'plugins'),
        resolveTaskName(name, 'include'),
        resolveTaskName(name, 'assets')
    ]);
};
