import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { stat } from 'node:fs/promises';
import { buildFile } from './index.js';

const cwd = dirname(fileURLToPath(import.meta.url));

describe('buildFile', () => {
  context('with .css.scss file extension', () => {
    it('writes a file with the same basename and a .css extension', async () => {
      const fixtureDir = join(cwd, 'fixtures/css-scss-extension');
      await buildFile(join(fixtureDir, 'styles.css.scss'), { outDir: fixtureDir });

      await stat(join(fixtureDir, 'styles.css'));
    });
  });

  context('with .scss file extension', () => {
    it('writes a file with the same basename and a .css extension', async () => {
      const fixtureDir = join(cwd, 'fixtures/scss-extension');
      await buildFile(join(fixtureDir, 'styles.scss'), { outDir: fixtureDir });

      await stat(join(fixtureDir, 'styles.css'));
    });
  });
});
