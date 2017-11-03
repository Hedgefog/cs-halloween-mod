const fs = require('fs');
const path = require('path');

const config = require('./user-config.resolver').thirdparty;
const constants = require('../constants');

const resolveThirdparty = (relativepPath) => path.join(config.dir, relativepPath);

const thirdpartyRelative = path.relative(process.cwd(), config.dir);

if (!fs.existsSync(resolveThirdparty(`${constants.reapiDir}/addons`))) {
    throw new Error(`extract ReAPI to "${thirdpartyRelative}/${constants.reapiDir}" directory`);
}

if (!fs.existsSync(resolveThirdparty(`${constants.roundControlDir}/addons`))) {
    throw new Error(`extract RoundControl to "${thirdpartyRelative}/${constants.roundControlDir}" directory`);
}

module.exports = resolveThirdparty;
