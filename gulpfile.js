const resolveThirdparty = require('./helpers/third-party.resolver');
const config = require('./helpers/user-config.resolver');
const generateReadme = require('./helpers/bundle-readme.generator');

const path = require('path');
const fs = require('fs');

const gulp = require('gulp');
const zip = require('gulp-zip');
const file = require('gulp-file');
const merge2 = require('merge2')

const resolveArchiveName = (sufix) => `hwn-${require('./package.json').version.replace(/\./g, '')}-${sufix}.zip`;
const resolveBundledDir = (name) => path.join(__dirname, `bundles/${name}`);
const resolveDestConfig = (destDir) => ({
    dir: destDir,
    includeDir: path.join(destDir, 'addons/amxmodx/scripting/include'),
    pluginsDir: path.join(destDir, 'addons/amxmodx/plugins'),
    scriptsDir: path.join(destDir, 'addons/amxmodx/scripting')
});

const defaultDestConfig = resolveDestConfig(config.build.default.destDir);

const defaultSmaConfig = {
    compiler: config.compiler.executable,
    dest: defaultDestConfig.pluginsDir,
    includeDir: config.project.includeDir
};

const buildTaskFactory = require('./helpers/build-task.factory');

buildTaskFactory('build:default', {
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
        dest: destConfig
    };
});

buildTaskFactory('watch', {
    smaConfig: defaultSmaConfig,
    dest: defaultDestConfig,
    watch: true
});

gulp.task('pack:alliedmods', () => {
    const distDir = config.build.default.destDir;

    if (!fs.existsSync(distDir)) {
        throw new Error('Build project before packing');
    }

    const buildDir = resolveBundledDir('alliedmods');

    return merge2(
        gulp.src([
            distDir + '/**',
            '!' + distDir + '/addons{,/**}',
        ])
            .pipe(zip(resolveArchiveName('resources')))
            .pipe(gulp.dest(buildDir)),
        gulp.src([
            distDir + '/addons{,/**}',
            '!' + distDir + '/addons/amxmodx/plugins{,/**}',
            '!' + distDir + '/addons/amxmodx/modules{,/**}',
        ])
            .pipe(zip(resolveArchiveName('addons')))
            .pipe(gulp.dest(buildDir))
    )
});

gulp.task('pack:full', () => {
    const distDir = config.build.default.destDir;
    const reapiDistDir = config.build.reapi.destDir;

    if (!fs.existsSync(distDir) || !fs.existsSync(reapiDistDir)) {
        throw new Error('Build project before packing');
    }

    const buildDir = resolveBundledDir('full');

    const archiveNames = {
        resources: resolveArchiveName('resources'),
        addons: resolveArchiveName('addons'),
        reapiAddons: resolveArchiveName('addons-reapi'),
        bundle: resolveArchiveName('bundle')
    };

    return merge2(
        [
            gulp.src([
                distDir + '/addons{,/**}',
                resolveThirdparty('round-control') + '/**'
            ])
                .pipe(zip(archiveNames.addons))
                .pipe(gulp.dest(buildDir)),

            gulp.src([
                reapiDistDir + '/addons{,/**}'
            ])
                .pipe(zip(archiveNames.reapiAddons))
                .pipe(gulp.dest(buildDir)),

            gulp.src([
                distDir + '/**',
                '!' + distDir + '/addons{,/**}',
            ])
                .pipe(zip(archiveNames.resources))
                .pipe(gulp.dest(buildDir)),

            file('README.TXT', generateReadme(archiveNames), {src: true})
                .pipe(gulp.dest(buildDir)),
        ],
    )
        .pipe(zip(archiveNames.bundle))
        .pipe(gulp.dest(buildDir));
});

gulp.task('pack:sdk', () => {
    const buildDir = resolveBundledDir('sdk');

    const sdkArchiveName = resolveArchiveName('sdk');

    return gulp.src([
        __dirname + '/sdk/**',
        __dirname + '/examples{,/**/*.map}',
    ])
        .pipe(zip(sdkArchiveName))
        .pipe(gulp.dest(buildDir));
});

gulp.task('pack', ['pack:alliedmods', 'pack:full', 'pack:sdk']);
gulp.task('default', ['build:default', 'build:reapi']);