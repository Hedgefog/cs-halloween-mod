const path = require('path');
const fs = require('fs');
const gulp = require('gulp');
const zip = require('gulp-zip');
const file = require('gulp-file');
const merge2 = require('merge2');

const package = require('./package.json');
const generateReadme = require('./helpers/bundle-readme.generator');

const WORK_DIR = process.cwd();
const DIST_DIR = path.join(WORK_DIR, './dist');
const BUILD_DIR = path.join(DIST_DIR, 'bundles');
const VANILLA_DIST_DIR = path.join(DIST_DIR, 'vanilla');
const REAPI_DIST_DIR = path.join(DIST_DIR, 'reapi');

if (!fs.existsSync(REAPI_DIST_DIR)) {
    throw new Error('Build ReAPI project before packing');
}

const resolveArchiveName = (sufix) => `${package.name}-${package.version.replace(/\./g, '')}-${sufix}.zip`;

const FILES = {
    bundleArchive: resolveArchiveName('bundle'),
    srcArchive: resolveArchiveName('addons-src'),
    addonsVanillaArchive: resolveArchiveName('addons'),
    addonsReapiArchive: resolveArchiveName('addons-reapi'),
    resourcesArchive: resolveArchiveName('resources'),
    sdkArchive: resolveArchiveName('sdk'),
    readme: 'README.TXT'
};

const BUNDLE_FILES = [
    { name: FILES.addonsVanillaArchive, description: 'compiled plugins and source code' },
    { name: FILES.addonsReapiArchive, description: 'compiled plugins for reapi and source code' },
    { name: FILES.resourcesArchive, description: 'mod resources' },
    { name: FILES.sdkArchive, description: 'mod sdk' }
];

gulp.task('pack:vanilla:bundles', () => {
    const dirPatterns = {
        all: VANILLA_DIST_DIR + '/**',
        addons: VANILLA_DIST_DIR + '/addons{,/**}',
        plugins: VANILLA_DIST_DIR + '/addons/amxmodx/plugins{,/**}',
        modules: VANILLA_DIST_DIR + '/addons/amxmodx/modules{,/**}',
        roundControl: path.join(WORK_DIR, '.thirdparty/round-control/roundcontrol_2.2/**'),
        sdk: WORK_DIR + '/sdk/**'
    };

    return merge2([
        gulp.src([dirPatterns.addons, '!' + dirPatterns.plugins, '!' + dirPatterns.modules])
            .pipe(zip(FILES.srcArchive)),
        gulp.src([dirPatterns.addons, dirPatterns.roundControl])
            .pipe(zip(FILES.addonsVanillaArchive)),
        gulp.src([dirPatterns.all, '!' + dirPatterns.addons])
            .pipe(zip(FILES.resourcesArchive)),
        gulp.src([dirPatterns.sdk])
            .pipe(zip(FILES.sdkArchive)),
        file(FILES.readme, generateReadme(BUNDLE_FILES), {src: true})
    ]).pipe(gulp.dest(BUILD_DIR));
});

gulp.task('pack:reapi:bundles', () => {
    const dirPatterns = {
        all: REAPI_DIST_DIR + '/**',
        addons: REAPI_DIST_DIR + '/addons{,/**}',
        plugins: REAPI_DIST_DIR + '/addons/amxmodx/plugins{,/**}',
        modules: REAPI_DIST_DIR + '/addons/amxmodx/modules{,/**}',
        sdk: WORK_DIR + '/sdk/**'
    };

    return merge2([
        gulp.src([dirPatterns.addons, '!' + dirPatterns.plugins, '!' + dirPatterns.modules])
            .pipe(zip(FILES.srcArchive)),
        gulp.src([dirPatterns.addons])
            .pipe(zip(FILES.addonsReapiArchive)),
        gulp.src([dirPatterns.all, '!' + dirPatterns.addons])
            .pipe(zip(FILES.resourcesArchive)),
        gulp.src([dirPatterns.sdk])
            .pipe(zip(FILES.sdkArchive)),
        file(FILES.readme, generateReadme(BUNDLE_FILES), {src: true})
    ]).pipe(gulp.dest(BUILD_DIR));
});

gulp.task('pack:bundles', gulp.series('pack:reapi:bundles', 'pack:vanilla:bundles'));

gulp.task('pack:full', () => {
    const bundleFiles = BUNDLE_FILES.map(file => path.join(BUILD_DIR, file.name));

    return gulp.src(bundleFiles)
        .pipe(zip(FILES.bundleArchive))
        .pipe(gulp.dest(BUILD_DIR))
})

gulp.task('default', gulp.series('pack:bundles', 'pack:full'));
