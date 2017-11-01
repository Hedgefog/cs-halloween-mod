const fs = require('fs');

if (!fs.existsSync('config.user.js')) {
    fs.writeFileSync('config.user.js', fs.readFileSync('config.js'));
}

module.exports = require('../config.user');
