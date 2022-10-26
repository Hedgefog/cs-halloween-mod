module.exports = Object.assign(require('./.amxxpack.json'), {
  include: [
    './.compiler/include',
    './.thirdparty/reapi/addons/amxmodx/scripting/include'
  ],
  output: {
    plugins: './dist/reapi/addons/amxmodx/plugins',
    scripts: './dist/reapi/addons/amxmodx/scripting',
    include: './dist/reapi/addons/amxmodx/scripting/include',
    assets: './dist/reapi'
  }
});
