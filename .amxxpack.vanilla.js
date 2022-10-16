module.exports = Object.assign(require('./.amxxpack.json'), {
  include: [
    './.compiler/include',
    './.thirdparty/round-control/roundcontrol_2.2/addons/amxmodx/scripting/include'
  ],
  output: {
    plugins: './dist/vanilla/addons/amxmodx/plugins',
    scripts: './dist/vanilla/addons/amxmodx/scripting',
    include: './dist/vanilla/addons/amxmodx/scripting/include',
    assets: './dist/vanilla'
  }
});
