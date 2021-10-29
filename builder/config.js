const path = require('path');
const os = require('os');

const compilerExecutable = os.platform() === 'win32' ? 'amxxpc.exe' : 'amxxpc';

module.exports = {
    version: '1.0.0',
    compiler: {
        dir: path.resolve('./compiler'),
        executable: path.resolve('./compiler/', compilerExecutable)
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
