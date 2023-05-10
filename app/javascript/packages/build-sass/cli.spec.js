import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { promisify } from 'node:util';
import { readFile } from 'node:fs/promises';
import { exec as execCallback } from 'node:child_process';

const exec = promisify(execCallback);
const cwd = dirname(fileURLToPath(import.meta.url));

describe('cli', () => {
  context('with individual files as positional arguments', () => {
    it('compiles all files matching the glob pattern', async () => {
      await exec(
        './cli.js fixtures/individual-files/a.css.scss fixtures/individual-files/b.css.scss --out-dir=fixtures/glob-patterns',
        { cwd },
      );

      const [aActual, aExpected, bActual, bExpected] = await Promise.all(
        ['a.css', 'a.expected.css', 'b.css', 'b.expected.css'].map((file) =>
          readFile(join(cwd, 'fixtures/individual-files', file), 'utf-8'),
        ),
      );

      expect(aActual).to.equal(aExpected);
      expect(bActual).to.equal(bExpected);
    });
  });

  context('with glob pattern', () => {
    it('compiles all files matching the glob pattern', async () => {
      await exec(`./cli.js "fixtures/glob-patterns/*.scss" --out-dir=fixtures/glob-patterns`, {
        cwd,
      });

      const [aActual, aExpected, bActual, bExpected] = await Promise.all(
        ['a.css', 'a.expected.css', 'b.css', 'b.expected.css'].map((file) =>
          readFile(join(cwd, 'fixtures/glob-patterns', file), 'utf-8'),
        ),
      );

      expect(aActual).to.equal(aExpected);
      expect(bActual).to.equal(bExpected);
    });
  });
});
