const path = require('path');

const userConfig = false;

module.exports = {
    version: '1.0.0',
    compiler: {
        executable: path.resolve('./compiler/amxxpc')
    },
    project: {
        includeDir: path.resolve('./src/include'),
    },
    sdk: {
        dir: path.resolve('./sdk')
    },
    thirdparty: {
        dir: path.resolve('./thirdparty')
    },
    build: {
        vanilla: {
            destDir: path.resolve('./dist/vanilla')
        },
        reapi: {
            destDir: path.resolve('./dist/reapi')
        },
        bundles: {
            destDir: path.resolve('./dist/bundles')
        }
    }
};
