module.exports = Object.assign(require('./.amxxpack.json'), {
  include: [
    './.compiler/include',
    './.thirdparty/reapi/addons/amxmodx/scripting/include'
  ],
  output: {
    plugins: 'C:/Program Files (x86)/Steam/steamapps/common/Half-Life/cstrike/addons/amxmodx/plugins',
    scripts: 'C:/Program Files (x86)/Steam/steamapps/common/Half-Life/cstrike/addons/amxmodx/scripting',
    include: 'C:/Program Files (x86)/Steam/steamapps/common/Half-Life/cstrike/addons/amxmodx/scripting/include',
    assets: 'C:/Program Files (x86)/Steam/steamapps/common/Half-Life/cstrike'
  }
});
