const fs = require('fs');
const path = require('path');

const configFilename = path.join('../config');
const userConfigFilename = path.join(process.cwd(), 'config.user.js');

if (!fs.existsSync(userConfigFilename)) {
    fs.writeFileSync(userConfigFilename, fs.readFileSync(configFilename));
}

module.exports = require(userConfigFilename);
