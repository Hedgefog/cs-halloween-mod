const path = require('path');

const DIST_DIR = path.join(__dirname, 'dist');

module.exports = {
    distDir: DIST_DIR,
    compiler: path.join(__dirname, 'compiler/amxxpc'),
    includeDir: path.join(__dirname, 'src/include'),
    pluginsDir: path.join(DIST_DIR, 'addons/amxmodx/plugins'),
    scriptsDir: path.join(DIST_DIR, 'addons/amxmodx/scripting'),
};
