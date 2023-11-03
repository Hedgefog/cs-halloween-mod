const path = require('path');
const fs = require('fs');
const gulp = require('gulp');
const zip = require('gulp-zip');
const file = require('gulp-file');
const merge2 = require('merge2');

const package = require('./package.json');

const README_INDENT = '    ';
const README_INSTALLATION_TEXT = 'Extract addons and resources to cstrike folder';
const WORK_DIR = process.cwd();
const DIST_DIR = path.join(WORK_DIR, './dist');
const DIST_BUILD_DIR = path.join(DIST_DIR, 'build');
const BUILD_DIR = path.join(DIST_DIR, 'bundles');
const BUILD_METADATA_FILE = path.join(DIST_DIR, 'bundles', 'files.json');
const SDK_DIR = path.join(WORK_DIR, 'sdk');
const ASSETS_DIR = path.join(WORK_DIR, 'assets');

if (!fs.existsSync(DIST_BUILD_DIR)) {
    throw new Error('Build project before packing');
}

function isDirEmpty(dir) {
    if (!fs.existsSync(dir)) {
        return true;
    }

    const files = fs.readdirSync(dir);

    return !files.length;
}

function generateReadme(files) {
    const filesArr = Object.keys(files).map(key => {
        const { name, description } = files[key];
        return { key, name, description };
    });

    const fileMaxLength = Math.max(
        ...filesArr.map(file => file.name.length)
    );

    const resolvedFiles = filesArr.map(file => {
        const { name, description } = file;

        if (!description) {
            return;
        }

        const spacesNum = Math.max(fileMaxLength - name.length, 0);
        const spaces = ' '.repeat(spacesNum);

        return `${README_INDENT}${name}${spaces} - ${description}`
    }).filter(Boolean).join('\n');

    return [
        '[INSTALLATION]',
        `${README_INDENT}${README_INSTALLATION_TEXT}`,
        '',
        '[FILES]',
        resolvedFiles
    ].join('\n');
}

const resolveArchiveName = (sufix) => `${package.name}-${package.version.replace(/\./g, '')}-${sufix}.zip`;

const FILES = {
    srcArchive: resolveArchiveName('addons-src'),
    buildArchive: resolveArchiveName('addons-build'),
    resourcesArchive: !isDirEmpty(ASSETS_DIR) ? resolveArchiveName('resources') : null,
    sdkArchive: !isDirEmpty(SDK_DIR) ? resolveArchiveName('sdk') : null,
    readme: 'README.TXT',
    bundleArchive: resolveArchiveName('bundle')
};

const BUNDLE_FILES = [
    { name: FILES.buildArchive, description: 'compiled plugins and source code' }
];

if (FILES.resourcesArchive) {
    BUNDLE_FILES.push({ name: FILES.resourcesArchive, description: 'mod resources' });
}

if (FILES.sdkArchive) {
    BUNDLE_FILES.push({ name: FILES.sdkArchive, description: 'mod sdk' });
}

gulp.task('pack:bundles', () => {
    const dirPatterns = {
        all: DIST_BUILD_DIR + '/**',
        addons: DIST_BUILD_DIR + '/addons{,/**}',
        plugins: DIST_BUILD_DIR + '/addons/amxmodx/plugins{,/**}',
        modules: DIST_BUILD_DIR + '/addons/amxmodx/modules{,/**}',
        sdk: SDK_DIR + '/**'
    };

    const zipTasks = [
        (
            gulp
                .src([dirPatterns.addons, '!' + dirPatterns.plugins, '!' + dirPatterns.modules])
                .pipe(zip(FILES.srcArchive))
        ),
        (
            gulp
                .src([dirPatterns.addons])
                .pipe(zip(FILES.buildArchive))
        )
    ];

    if (FILES.resourcesArchive) {
        zipTasks.push(
            gulp
                .src([dirPatterns.all, '!' + dirPatterns.addons])
                .pipe(zip(FILES.resourcesArchive))
        );
    }

    if(FILES.sdkArchive) {
        zipTasks.push(
            gulp
                .src([dirPatterns.sdk])
                .pipe(zip(FILES.sdkArchive))
        );
    }

    return merge2([
        ...zipTasks,
        file(FILES.readme, generateReadme(BUNDLE_FILES), { src: true })
    ]).pipe(gulp.dest(BUILD_DIR));
});

gulp.task('pack:full', () => {
    const bundleFiles = BUNDLE_FILES.map(file => path.join(BUILD_DIR, file.name));

    return gulp.src(bundleFiles)
        .pipe(zip(FILES.bundleArchive))
        .pipe(gulp.dest(BUILD_DIR))
});

gulp.task('pack:metadata', cb => {
    fs.writeFile(BUILD_METADATA_FILE, JSON.stringify(FILES), cb);
});

gulp.task('default', gulp.series('pack:bundles', 'pack:full', 'pack:metadata'));
