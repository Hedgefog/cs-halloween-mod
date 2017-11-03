const fs = require('fs');
const path = require('path');

const config = require('./user-config.resolver');
const constants = require('../constants');

const resolveThirdparty = (relativepPath) => path.join(config.thirdparty.dir, relativepPath);

const compilerRelative = path.relative(process.cwd(), config.compiler.dir);

if (!fs.existsSync(config.compiler.executable)) {
    throw new Error(`extract amxxpc compiler to "${compilerRelative}" directory`);
}

const thirdpartyRelative = path.relative(process.cwd(), config.thirdparty.dir);

if (!fs.existsSync(resolveThirdparty(`${constants.reapiDir}/addons`))) {
    throw new Error(`extract ReAPI to "${thirdpartyRelative}/${constants.reapiDir}" directory`);
}

if (!fs.existsSync(resolveThirdparty(`${constants.roundControlDir}/addons`))) {
    throw new Error(`extract RoundControl to "${thirdpartyRelative}/${constants.roundControlDir}" directory`);
}

module.exports = resolveThirdparty;
