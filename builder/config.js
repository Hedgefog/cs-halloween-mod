const path = require('path');

const userConfig = false;

module.exports = {
    compiler: {
        executable: path.join(__dirname, 'compiler/amxxpc')
    },
    project: {
        includeDir: path.join(__dirname, 'src/include'),
    },
    sdk: {
        dir: path.join(__dirname, 'sdk')
    },
    thirdparty: {
        dir: path.join(__dirname, 'thirdparty')
    },
    build: {
        default: {
            destDir: path.join(__dirname, 'dist')
        },
        reapi: {
            destDir: path.join(__dirname, 'dist_reapi')
        }
    }
};
