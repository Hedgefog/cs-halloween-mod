const ARCHIVE_NAME_MAXLEN = 48;
const JOIN_STR = '\r\n';
const INDENT = '    ';
const INSTALLATION_TEXT = 'Extract addons and resources to cstrike folder';

function getFilesList(prefix, files) {
  return Object.keys(files).map(key => {
    const { name, description } = files[key];

    if (!description) {
      return;
    }

    const spaces = ' '.repeat(ARCHIVE_NAME_MAXLEN - name.length);

    return `${prefix}${name}${spaces} - ${description}`
  }).filter(str => !!str).join(JOIN_STR);
}

module.exports = (files) => [
  '[INSTALLATION]',
  `${INDENT}${INSTALLATION_TEXT}`,
  '',
  '[FILES]',
  getFilesList(INDENT, files)
].join(JOIN_STR);
