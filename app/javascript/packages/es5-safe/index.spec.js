import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';
import { isSafe, isAllSafe } from './index.js';

const currentDir = dirname(fileURLToPath(import.meta.url));

describe('es5-safe', () => {
  describe('isSafe', () => {
    it('returns false and logs for unsafe file', async () => {
      const result = await isSafe(resolve(currentDir, 'spec/fixtures/unsafe.js'));

      expect(result).to.be.false();
      expect(console).to.have.loggedError();
    });

    it('returns true for safe file', async () => {
      const result = await isSafe(resolve(currentDir, 'spec/fixtures/safe.js'));

      expect(result).to.be.true();
    });
  });

  describe('isAllSafe', () => {
    it('returns false and logs for pattern include unsafe file', async () => {
      const result = await isAllSafe([resolve(currentDir, 'spec/fixtures/*.js')]);

      expect(result).to.be.false();
      expect(console).to.have.loggedError();
    });

    it('returns true for pattern include all safe files', async () => {
      const result = await isAllSafe([resolve(currentDir, 'spec/fixtures/safe.js')]);

      expect(result).to.be.true();
    });
  });
});
