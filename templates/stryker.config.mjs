// Chaque module est associé aux seuls fichiers de test capables de tuer ses
// mutants : la CI lance un job par module (variable MUTATE, voir
// .github/scripts/mutation-matrix.mjs) et le runner « command » ne relance que
// ces tests-là pour chaque mutant.
export const targets = {
  'worker/reducer.ts': ['worker/reducer.test.ts'],
  'shared/quantity.ts': ['shared/quantity.test.ts'],
  // Gros fichier : une clé par plage de lignes (`fichier:début-fin`), un job de
  // CI chacune. Partir de ~75 lignes ; redécouper les jobs > ~8 min.
  'src/App.tsx:1-75': ['src/App.test.tsx'],
  'src/App.tsx:76-150': ['src/App.test.tsx'],
};

const selected = process.env.MUTATE ? process.env.MUTATE.split(',') : Object.keys(targets);
for (const file of selected) {
  if (!targets[file]) throw new Error(`MUTATE : module inconnu ${file}`);
}
const tests = [...new Set(selected.flatMap((file) => targets[file]))];

export default {
  packageManager: 'npm',
  // Runner « command » : le plugin vitest de Stryker n'exécute que 0 à 1 test
  // par mutant, ce qui laisse tout « survivre ».
  testRunner: 'command',
  commandRunner: { command: `npx vitest run ${tests.join(' ')}` },
  coverageAnalysis: 'off',
  // Contournement TypeScript 7 : fichier volontairement absent (le
  // préprocesseur de Stryker appelle une API retirée).
  tsconfigFile: 'tsconfig.stryker-unused.json',
  mutate: selected,
  reporters: ['clear-text', 'progress', 'html'],
  htmlReporter: { fileName: 'mutation-report/index.html' },
  thresholds: { high: 100, low: 100, break: 100 },
  tempDirName: '.stryker-tmp',
  cleanTempDir: true,
};
