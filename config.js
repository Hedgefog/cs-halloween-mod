const path = require('path');

const userConfig = false;

const DIST_DIR = userConfig
    ? 'D:/Steam/steamapps/common/Half-Life/cstrike'
    : path.join(__dirname, 'dist');

const REAPI_DIST_DIR = path.join(__dirname, 'dist_reapi');

module.exports = {
    compiler: {
        executable: path.join(__dirname, 'compiler/amxxpc')
    },
    project: {
        includeDir: path.join(__dirname, 'src/include'),
    },
    dest: {
        dir: DIST_DIR,
        includeDir: path.join(DIST_DIR, 'addons/amxmodx/scripting/include'),
        pluginsDir: path.join(DIST_DIR, 'addons/amxmodx/plugins'),
        scriptsDir: path.join(DIST_DIR, 'addons/amxmodx/scripting')
    },
    reapi: {
        includeDir: path.join(__dirname, 'reapi/include'),
        dest: {
            dir: REAPI_DIST_DIR,
            includeDir: path.join(REAPI_DIST_DIR, 'addons/amxmodx/scripting/include'),
            pluginsDir: path.join(REAPI_DIST_DIR, 'addons/amxmodx/plugins'),
            scriptsDir: path.join(REAPI_DIST_DIR, 'addons/amxmodx/scripting')
        }
    }
};
