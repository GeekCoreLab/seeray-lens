import { execFileSync } from 'node:child_process';
import { existsSync } from 'node:fs';
import { copyFile, mkdir, readFile, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';

const trackerRoot = resolve(import.meta.dirname, '..');
const resources = resolve(trackerRoot, '../server/src/main/resources/META-INF/resources');
const trackerOnly = process.argv.includes('--tracker-only');

const localEsbuild = resolve(trackerRoot, 'node_modules/.bin/esbuild');
const esbuildBin = existsSync(localEsbuild) ? localEsbuild : 'esbuild';

const rawTracker = await readFile(resolve(trackerRoot, 'dist/index.global.js'), 'utf8');
const tracker = rawTracker.replace(/\n?\/\/# sourceMappingURL=.*$/m, '');
const bootstrap = execFileSync(
  esbuildBin,
  [resolve(trackerRoot, 'src/bootstrap.js'), '--minify', '--charset=utf8'],
  { encoding: 'utf8' },
);

await writeFile(
  resolve(resources, 'tracker.js'),
  `${tracker.trimEnd()}\n${bootstrap.trimEnd()}\n`,
);
if (!trackerOnly) {
  await copyFile(resolve(trackerRoot, 'dist/recorder.js'), resolve(resources, 'recorder.js'));
  await copyFile(resolve(trackerRoot, 'dist/replayer.js'), resolve(trackerRoot, '../admin/web/replayer.js'));
  await mkdir(resolve(trackerRoot, '../admin/assets'), { recursive: true });
  await copyFile(resolve(trackerRoot, 'dist/replayer.js'), resolve(trackerRoot, '../admin/assets/replayer.js'));
}
