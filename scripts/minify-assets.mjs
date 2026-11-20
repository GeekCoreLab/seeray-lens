import { execFileSync, spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';

const projectRoot = path.resolve(import.meta.dirname, '..');
const defaultResourcesDir = path.join(
    projectRoot,
    'server',
    'build',
    'resources',
    'main',
    'META-INF',
    'resources',
);
const resourcesRoot = process.argv[2] ? path.resolve(process.argv[2]) : defaultResourcesDir;

// Already minified by tracker/package.json (tsup --minify + publish-server-assets.mjs).
const PREMINIFIED_ASSETS = new Set(['tracker.js', 'recorder.js']);

function findEsbuild() {
    if (process.env.ESBUILD_BIN && fs.existsSync(process.env.ESBUILD_BIN)) {
        return process.env.ESBUILD_BIN;
    }

    const candidates = [
        'esbuild',
        path.join(projectRoot, 'tracker', 'node_modules', '.bin', 'esbuild'),
        path.join(projectRoot, 'node_modules', '.bin', 'esbuild'),
    ];

    try {
        const npmPrefix = execFileSync('npm', ['prefix', '-g'], {
            encoding: 'utf8',
            stdio: ['ignore', 'pipe', 'ignore'],
        }).trim();
        if (npmPrefix) {
            candidates.push(path.join(npmPrefix, 'bin', 'esbuild'));
        }
    } catch {
        // Ignore npm prefix lookup failure
    }

    for (const candidate of candidates) {
        const probe = spawnSync(candidate, ['--version'], {
            encoding: 'utf8',
            stdio: ['ignore', 'pipe', 'ignore'],
        });
        if (probe.status === 0) {
            return candidate;
        }
    }
    return null;
}

function collectAssetFiles(dir, baseDir = dir) {
    if (!fs.existsSync(dir)) {
        return [];
    }
    const results = [];
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
        const fullPath = path.join(dir, entry.name);
        if (entry.isDirectory()) {
            results.push(...collectAssetFiles(fullPath, baseDir));
            continue;
        }
        if (!entry.isFile()) {
            continue;
        }
        const relPath = path.relative(baseDir, fullPath).replace(/\\/g, '/');
        if (PREMINIFIED_ASSETS.has(relPath)) {
            continue;
        }
        const isJs = entry.name.endsWith('.js') && !entry.name.endsWith('.min.js');
        const isCss = entry.name.endsWith('.css') && !entry.name.endsWith('.min.css');
        if (isJs || isCss) {
            results.push(fullPath);
        }
    }
    return results;
}

function main() {
    if (!fs.existsSync(resourcesRoot)) {
        console.log(`[minify-assets] ${resourcesRoot} not found, skipping.`);
        return;
    }

    const files = collectAssetFiles(resourcesRoot);
    if (files.length === 0) {
        console.log('[minify-assets] No unminified JS/CSS assets found, skipping.');
        return;
    }

    const esbuildBin = findEsbuild();
    if (!esbuildBin) {
        console.log('[minify-assets] esbuild not found; skipping minification (unminified assets will be served).');
        return;
    }

    const start = Date.now();
    for (const filePath of files) {
        execFileSync(
            esbuildBin,
            [
                filePath,
                '--minify',
                '--charset=utf8',
                '--allow-overwrite',
                `--outfile=${filePath}`,
            ],
            { stdio: 'inherit' },
        );
    }
    const elapsed = Date.now() - start;

    console.log(`[minify-assets] Minified ${files.length} asset(s) in ${elapsed}ms using ${esbuildBin}.`);
}

main();
