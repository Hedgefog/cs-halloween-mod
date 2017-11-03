const path = require('path');

const gulp = require('gulp');

const resolveThirdparty = require('../resolvers/thirdparty.resolver');
const config = require('../resolvers/user-config.resolver');

const buildTaskFactory = require('../factories/build-task.factory');

const constants = require('../constants');

const resolveDestConfig = (destDir) => ({
    dir: destDir,
    includeDir: path.join(destDir, 'addons/amxmodx/scripting/include'),
    pluginsDir: path.join(destDir, 'addons/amxmodx/plugins'),
    scriptsDir: path.join(destDir, 'addons/amxmodx/scripting')
});

const buildTasks = [];
const watchTasks = [];

// vanilla server

if (config.build.vanilla) {
    const vanillaDestConfig = resolveDestConfig(config.build.vanilla.destDir);
    const vanillaSmaConfig = {
        compiler: config.compiler.executable,
        dest: vanillaDestConfig.pluginsDir,
        includeDir: [
            resolveThirdparty(`${constants.roundControlDir}/addons/amxmodx/scripting/include`),
            config.project.includeDir
        ]
    };

    buildTaskFactory('build:vanilla', {
        smaConfig: vanillaSmaConfig,
        dest: vanillaDestConfig
    });
    
    buildTaskFactory('watch:vanilla', {
        smaConfig: vanillaSmaConfig,
        dest: vanillaDestConfig,
        watch: true
    });

    buildTasks.push('build:vanilla');
    watchTasks.push('watch:vanilla');
}

// ReAPI server

if (config.build.reapi) {
    const reapiDestConfig = resolveDestConfig(config.build.reapi.destDir);
    const reapiSmaConfig = {
        compiler: config.compiler.executable,
        dest: reapiDestConfig.pluginsDir,
        includeDir: [
            resolveThirdparty(`${constants.reapiDir}/addons/amxmodx/scripting/include`),
            config.project.includeDir
        ]
    }

    buildTaskFactory('watch:reapi', {
        smaConfig: reapiSmaConfig,
        dest: reapiDestConfig,
        watch: true
    });

    buildTaskFactory('build:reapi', {
        smaConfig: reapiSmaConfig,
        dest: reapiDestConfig
    });

    buildTasks.push('build:reapi');
    watchTasks.push('watch:reapi');
}

// final tasks

gulp.task('build', buildTasks);
gulp.task('watch', watchTasks);
