const fs = require('fs');
const glob = require('glob');
const { map, flatMap, filter, sortBy } = require('lodash');

function escapeStringQuotes(str) {
  return /"(.*)"/.exec(str);
}

function getPluginName(src) {
  const [, name] = /register_plugin\((.*), (.*), (.*)\)/.exec(src) || [];

  if (name.startsWith('"')) {
    return escapeStringQuotes(name);
  }

  const regExp = new RegExp(`\\s*#define\\s+${name}\\s+\\"(.*)\\"`, "gm");
  const [, definedName] = regExp.exec(src) || [];
  return definedName;
}

function getCvars(src) {
  const cvarExpList = src.match(/register_cvar\((.*)\)/gm);
  if (!cvarExpList) {
    return [];
  }

  const cvars = flatMap(cvarExpList, code => {
    const [, name, value] = /register_cvar\("(.*)", "(.*)"\)/.exec(code) || [];
    return {name, value: /^([0-9\.])+$/.test(value) ? +value : value };
  });

  return sortBy(cvars, 'name');
}

function readPluginInfo(file) {
  const src = fs.readFileSync(file, "utf8");
  const name = getPluginName(src);
  const cvars = getCvars(src);

  return  { file, name, cvars };
}

function createConfig() {
  const files = glob.sync(process.cwd() + "/src/scripts/**/*.sma");

  const plugins = filter(
    sortBy(
      map(files, readPluginInfo),
      'file'
    ),
    plugin => !!plugin.cvars.length
  );

  return plugins.map(
    plugin => [
      `// ${plugin.name}`,
      plugin.cvars.map(
        cvar => {
          const value = typeof cvar.value === 'number' ? cvar.value : `"${cvar.value}"`;
          return [cvar.name, value].join(' ');
        }
      ).join('\n')
    ].join('\n')
  ).join('\n\n') + '\n';
}

fs.writeFileSync(process.cwd() + '/assets/addons/amxmodx/configs/hwn.cfg', createConfig());
