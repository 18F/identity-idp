import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { promisify } from 'node:util';
import { stat } from 'node:fs/promises';
import { exec as execCallback } from 'node:child_process';

const exec = promisify(execCallback);
const cwd = dirname(fileURLToPath(import.meta.url));

describe('cli', () => {
  context('with missing output directory', () => {
    it('creates the output directory', async () => {
      await exec(
        './cli.js fixtures/missing-out-dir/in.css.scss --out-dir=fixtures/missing-out-dir/out',
        { cwd },
      );

      await stat(join(cwd, 'fixtures/missing-out-dir/in.css.scss'));
    });
  });

  context('with unconfigured output directory', () => {
    it('outputs in the same directory as the input file', async () => {
      await exec('./cli.js fixtures/default-out-dir/styles.css.scss', { cwd });

      await stat(join(cwd, 'fixtures/default-out-dir/styles.css'));
    });
  });
});
