const path = require('path');

const userConfig = false;

module.exports = {
    compiler: {
        executable: path.join(__dirname, 'compiler/amxxpc')
    },
    project: {
        includeDir: path.join(__dirname, 'src/include'),
    },
    build: {
        default: {
            destDir: path.join(__dirname, 'dist')
        },
        game: {
            destDir: 'D:/Steam/steamapps/common/Half-Life/cstrike'
        },
        reapi: {
            destDir: path.join(__dirname, 'dist_reapi')
        }
    }
};
