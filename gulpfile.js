const gulp = require('gulp');
const zip = require('gulp-zip');

const path = require('path');
const fs = require('fs');

const buildTaskFactory = require('./build-task-factory');

const config = require('./config');
const package = require('./package.json');

const resolveArchiveName = (sufix) => `hwn-${package.version.replace(/\./g, '')}-${sufix}.zip`;
const resolveBundledDir = (name) => `bundles/${name}`;
const resolveThirdparty = (relativepPath) => path.join(__dirname, 'thirdparty', relativepPath);
const resolveDestConfig = (destDir) => ({
    dir: destDir,
    includeDir: path.join(destDir, 'addons/amxmodx/scripting/include'),
    pluginsDir: path.join(destDir, 'addons/amxmodx/plugins'),
    scriptsDir: path.join(destDir, 'addons/amxmodx/scripting')
});

const defaultDestConfig = resolveDestConfig(config.build.default.destDir);
const gameDestConfig = resolveDestConfig(config.build.game.destDir);

const defaultSmaConfig = {
    compiler: config.compiler.executable,
    dest: defaultDestConfig.pluginsDir,
    includeDir: config.project.includeDir
};

const gameSmaConfig = {
    compiler: config.compiler.executable,
    dest: gameDestConfig.pluginsDir,
    includeDir: config.project.includeDir
};

buildTaskFactory('build', {
    smaConfig: defaultSmaConfig,
    dest: defaultDestConfig
});

buildTaskFactory('build:reapi', () => {
    const destConfig = resolveDestConfig(config.build.reapi.destDir);

    return {
        smaConfig: {
            compiler: config.compiler.executable,
            dest: destConfig.pluginsDir,
            includeDir: [
                resolveThirdparty('reapi/addons/amxmodx/scripting/include'),
                config.project.includeDir
            ]
        },
        dest: destConfig,
        tasks: {
            assets: false
        }
    };
});

buildTaskFactory('watch', {
    smaConfig: defaultSmaConfig,
    dest: defaultDestConfig,
    watch: true
});

buildTaskFactory('build-game', {
    smaConfig: gameSmaConfig,
    dest: gameDestConfig,
    extraTasks: {
        roundControl: () => gulp.src(resolveThirdparty('round-control') + '/**')
            .pipe(gulp.dest(config.build.default.destDir))
    }
});

buildTaskFactory('watch-game', {
    smaConfig: gameSmaConfig,
    dest: defaultDestConfig,
    watch: true
});

gulp.task('pack:alliedmods', () => {
    const distDir = config.build.default.destDir;
    const buildDir = resolveBundledDir('alliedmods');

    gulp.src([
        distDir + '/**',
        '!' + distDir + '/addons{,/**}',
    ])
        .pipe(zip(resolveArchiveName('resources')))
        .pipe(gulp.dest(buildDir));

    gulp.src([
        distDir + '/addons{,/**}',
        '!' + distDir + '/addons/amxmodx/plugins{,/**}',
        '!' + distDir + '/addons/amxmodx/modules{,/**}',
    ])
        .pipe(zip(resolveArchiveName('addons')))
        .pipe(gulp.dest(buildDir));
});

gulp.task('pack:full', () => {
    const distDir = config.build.default.destDir;
    const reapiDistDir = config.build.default.destDir;
    const buildDir = resolveBundledDir('full');

    gulp.src([
        distDir + '/**',
        '!' + distDir + '/addons{,/**}',
    ])
        .pipe(zip(resolveArchiveName('resources')))
        .pipe(gulp.dest(buildDir));

    gulp.src([
        distDir + '/addons{,/**}',
        resolveThirdparty('round-control') + '/**'
    ])
        .pipe(zip(resolveArchiveName('addons')))
        .pipe(gulp.dest(buildDir));

    gulp.src([
        reapiDistDir + '/addons{,/**}',
    ])
        .pipe(zip(resolveArchiveName('addons-reapi')))
        .pipe(gulp.dest(buildDir));

    fs.writeFileSync(path.join(buildDir, 'README.TXT'), [
        `${resolveArchiveName('addons')} - addons for vanilla server`,
        `${resolveArchiveName('addons-reapi')} - addons for ReAPI`,
        `${resolveArchiveName('resources')} - resources`
    ].join('\r\n'));
});

gulp.task('pack', ['pack:alliedmods', 'pack:full']);
gulp.task('default', ['build', 'build:reapi']);