const fs = require('fs');
const path = require('path');

const resolveThirdparty = (relativepPath) => path.join(__dirname, '../thirdparty', relativepPath);

if (!fs.existsSync(resolveThirdparty('reapi/addons'))) {
    throw new Error('extract ReAPI to "thirdparty/reapi" directory');
}

if (!fs.existsSync(resolveThirdparty('round-control/addons'))) {
    throw new Error('extract RoundControl to "thirdparty/round-control" directory');
}

module.exports = resolveThirdparty;
