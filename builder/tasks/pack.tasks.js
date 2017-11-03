const resolveThirdparty = require('../resolvers/thirdparty.resolver');

const generateReadme = require('../generators/bundle-readme.generator');

const config = require('../resolvers/user-config.resolver');
const constants = require('../constants');

const path = require('path');
const fs = require('fs');

const gulp = require('gulp');
const zip = require('gulp-zip');
const file = require('gulp-file');
const merge2 = require('merge2');

const package = require(
    path.join(process.cwd(), 'package.json')
);

const resolveArchiveName = (sufix) => `hwn-${package.version.replace(/\./g, '')}-${sufix}.zip`;
const resolveBundledDir = (name) => path.join(config.build.bundles.destDir, name);

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
                resolveThirdparty(constants.roundControlDir) + '/**'
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
        config.sdk.dir + '/**'
    ])
        .pipe(zip(sdkArchiveName))
        .pipe(gulp.dest(buildDir));
});

gulp.task('pack', ['pack:alliedmods', 'pack:full', 'pack:sdk']);
gulp.task('default', ['build:default', 'build:reapi']);
