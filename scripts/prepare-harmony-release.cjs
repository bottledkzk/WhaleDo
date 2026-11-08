// Stage the course distribution variant without modifying the development manifest.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const source = path.resolve(__dirname, '../harmony');
const argument = process.argv[2];
if (!argument) throw new Error('Usage: node scripts/prepare-harmony-release.cjs <ASCII staging directory>');
const target = path.resolve(argument);
if (/[^\x00-\x7f]/.test(target)) throw new Error('Hvigor staging directory must contain ASCII characters only.');
if (target === source || target.startsWith(source + path.sep) || source.startsWith(target + path.sep)) {
  throw new Error('Choose a separate staging directory.');
}
const marker = path.join(target, '.whaledo-course-release');
if (fs.existsSync(target) && !fs.existsSync(marker) && fs.readdirSync(target).length) {
  throw new Error('Refusing to overwrite an existing directory not created by this script.');
}
fs.mkdirSync(target, { recursive: true });
fs.writeFileSync(marker, 'WhaleDo course release staging\n');
const omitted = new Set(['.git', '.hvigor', 'oh_modules', 'node_modules', 'build']);
function copy(dir, output) {
  fs.mkdirSync(output, { recursive: true });
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (omitted.has(entry.name)) continue;
    if (entry.isSymbolicLink()) throw new Error('Symlinks are not supported in release inputs.');
    if (entry.isDirectory()) copy(path.join(dir, entry.name), path.join(output, entry.name));
    else fs.copyFileSync(path.join(dir, entry.name), path.join(output, entry.name));
  }
}
copy(source, target);
const manifestPath = path.join(target, 'entry/src/main/module.json5');
const original = fs.readFileSync(manifestPath);
const manifest = JSON.parse(original.toString('utf8'));
const excludedPermission = 'ohos.permission.PUBLISH_AGENT_REMINDER';
manifest.module.requestPermissions = manifest.module.requestPermissions.filter(p => p.name !== excludedPermission);
const staged = JSON.stringify(manifest, null, 2) + '\n';
fs.writeFileSync(manifestPath, staged);
const sha256 = input => crypto.createHash('sha256').update(input).digest('hex');
const recipe = {
  variant: 'course-release', buildMode: 'release',
  bundleName: JSON.parse(fs.readFileSync(path.join(target, 'AppScope/app.json5'), 'utf8')).app.bundleName,
  excludedPermission, sourceManifestSha256: sha256(original), stagedManifestSha256: sha256(staged),
  reason: 'Agent reminder capability is not approved. Calendar ACL remains subject to the issued release Profile.'
};
fs.writeFileSync(path.join(target, 'course-release-recipe.json'), JSON.stringify(recipe, null, 2) + '\n');
console.log(JSON.stringify({ stagingDirectory: target, ...recipe }, null, 2));
