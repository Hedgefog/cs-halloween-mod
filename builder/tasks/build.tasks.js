const resolveThirdparty = require('../resolvers/thirdparty.resolver');
const config = require('../resolvers/user-config.resolver');
const constants = require('../constants');

const path = require('path');

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
    includeDir: [
        resolveThirdparty(`${constants.roundControlDir}/addons/amxmodx/scripting/include`),
        config.project.includeDir
    ]
};

const buildTaskFactory = require('../factories/build-task.factory');

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
              resolveThirdparty(`${constants.roundControlDir}/addons/amxmodx/scripting/include`),
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
