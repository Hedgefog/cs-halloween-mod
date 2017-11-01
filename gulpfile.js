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

gulp.task('plugins', () => {
    return gulp.src('./src/scripts/**/*.sma')
        .pipe(sma(smaParams))
        .pipe(flatten())
        .pipe(gulp.dest(config.dest.scriptsDir));
});

gulp.task('include', () => {
    return gulp.src('./src/include/*.inc')
        .pipe(gulp.dest(config.dest.includeDir));
});

gulp.task('assets', () => {
    return gulp.src('./assets/**/*')
        .pipe(gulp.dest(config.dest.dir));
});

gulp.task('plugins:reapi', () => {
    return gulp.src('./src/scripts/**/*.sma')
        .pipe(sma(reapiSmaParams))
        .pipe(flatten())
        .pipe(gulp.dest(config.reapi.dest.scriptsDir));
});

gulp.task('include:reapi', () => {
    return gulp.src('./src/include/*.inc')
        .pipe(gulp.dest(config.reapi.dest.includeDir));
});

gulp.task('assets:reapi', () => {
    return gulp.src('./assets/**/*')
        .pipe(gulp.dest(config.reapi.dest.dir));
});

gulp.task('plugins:watch', () => {
    return watch('./src/scripts/**/*.sma', {ignoreInitial: false})
        .pipe(sma(smaParams))
        .pipe(flatten())
        .pipe(gulp.dest(config.dest.scriptsDir));
});

gulp.task('include:watch', () => {
    return watch('./src/include/*.inc', {ignoreInitial: false})
        .pipe(gulp.dest(config.dest.includeDir));
});

gulp.task('assets:watch', () => {
    return watch('./assets/**/*', {ignoreInitial: false})
        .pipe(gulp.dest(config.dest.dir));
});

gulp.task('default', ['plugins', 'plugins', 'include', 'assets']);
gulp.task('reapi', ['plugins:reapi', 'plugins:reapi', 'include:reapi', 'assets:reapi']);
gulp.task('watch', ['plugins:watch', 'include:watch', 'assets:watch']);