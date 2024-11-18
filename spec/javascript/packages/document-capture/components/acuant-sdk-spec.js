/**
 * Acuant SDK Loading Tests
 *
 */
import fs from 'node:fs/promises';
import path from 'node:path';

import { JSDOM } from 'jsdom';

const ACUANT_PUBLIC_DIR = '../../../../../public/acuant';
const VERSION_REGEX = /^\d+\.\d+\.\d+$/;

describe('Acuant SDK Loading Tests', async () => {
  const sdks = (await fs.readdir(path.join(__dirname, ACUANT_PUBLIC_DIR))).filter((dir) => VERSION_REGEX.test(dir));

  if (!sdks.length) {
    throw new Error('Expected to find at least one SDK version, but found none');
  }

  sdks.forEach((version) => {
    describe(version, () => {
      const TEST_URL = `file://${__dirname}/index.html`;

      const { window } = new JSDOM('<!doctype html><html lang="en"><head><title>JSDOM</title></head></html>', {
        url: TEST_URL,
        runScripts: 'dangerously',
        resources: 'usable',
      });

      const { document } = window;

      before((done) => {
        const scriptEl = document.createElement('script');
        scriptEl.id = 'test-acuant-sdk-script';
        scriptEl.onload = () => {
          done();
        };
        scriptEl.src = `${ACUANT_PUBLIC_DIR}/${version}/AcuantJavascriptWebSdk.min.js`;
        document.body.append(scriptEl);
      });

      it('There is a script element in the DOM', () => {
        const found = document.getElementById('test-acuant-sdk-script');
        expect(found).to.exist();
      });

      it('Has a global loadAcuantSdk object on the window', () => {
        expect(window.loadAcuantSdk).to.exist();
      });

      it('Calling loadAcuantSdk gives us AcuantJavascriptWebSdk as a prop of the window', () => {
        window.loadAcuantSdk();
        expect(window).to.have.property('AcuantJavascriptWebSdk');
      });
    });
  });
});
