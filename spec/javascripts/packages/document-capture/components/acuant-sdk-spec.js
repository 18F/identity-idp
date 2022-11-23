/**
 * Acuant SDK Loading Tests
 *
 */
import { JSDOM } from 'jsdom';
import AcuantJavascriptWebSdk from '../../../../../public/acuant/11.7.1/AcuantJavascriptWebSdk.min.js';

const sdkPaths = {
  '11.7.1': '../../../../../public/acuant/11.7.1/AcuantJavascriptWebSdk.min.js',
};

const TEST_URL = `file://${__dirname}/index.html`;

const { window } = new JSDOM(
  '<!doctype html><html lang="en"><head><title>JSDOM</title></head></html>',
  {
    url: TEST_URL,
    runScripts: 'dangerously',
    resources: 'usable',
  },
);
const { document } = window;

describe('Acuant SDK Loading Tests', () => {
  it('Can load something from the SDK file', () => {
    expect(AcuantJavascriptWebSdk).to.exist();
  });
  describe('DOM Loading 11.7.1', () => {
    before((done) => {
      const scriptEl = document.createElement('script');
      scriptEl.id = 'test-acuant-sdk-script';
      scriptEl.onload = () => {
        done();
      };
      scriptEl.src = sdkPaths['11.7.1'];
      document.body.append(scriptEl);
    });
    it('There is a script element in the DOM', () => {
      const found = document.getElementById('test-acuant-sdk-script');
      expect(found).to.exist();
    });
    it('Has a global loadAcuantSdk object on the window', () => {
      expect(window.loadAcuantSdk).to.exist();
    });
    it('Calling loadAcuantSdk gives us AcuantJavascriptWebSdk in the global scope and as a prop of the window', () => {
      window.loadAcuantSdk();
      expect(AcuantJavascriptWebSdk).to.exist();
      expect(window.AcuantJavascriptWebSdk).to.exist();
    });
  });
});
