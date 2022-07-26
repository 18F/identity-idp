/**
 * Acuant SDK Loading Tests
 *
 */
import { JSDOM } from 'jsdom';
import AcuantJavascriptWebSdk from '../../../../../public/acuant/11.7.0/AcuantJavascriptWebSdk.min.js';
import fs from 'fs';
import path from 'path';

const sdkPaths = {
  '11.7.0': '../../../../../public/acuant/11.7.0/AcuantJavascriptWebSdk.min.js',
  '11.5.0': '../../../../../public/acuant/11.5.0/AcuantJavascriptWebSdk.min.js',
};

const scriptContent = fs
  .readFileSync(
    path.resolve(__dirname, '../../../../../public/acuant/11.7.0/AcuantJavascriptWebSdk.min.js'),
  )
  .toString();

const TEST_URL = `file://${__dirname}/index.html`;

let window = new JSDOM('<!doctype html><html lang="en"><head><title>JSDOM</title></head></html>', {
  url: TEST_URL,
  runScripts: 'dangerously',
  resources: 'usable',
}).window;
let document = window.document;

describe('Acuant SDK Loading Tests', () => {
  it('Can load something from the SDK file', () => {
    expect(AcuantJavascriptWebSdk).to.exist();
  });
  describe('DOM Loading 11.7.0', () => {
    before((done) => {
      let scriptEl = document.createElement('script');
      scriptEl.id = 'test-acuant-sdk-script';
      //scriptEl.textContent = scriptContent;
      scriptEl.onload = () => {
        done();
      };
      scriptEl.src = sdkPaths['11.7.0'];
      document.body.append(scriptEl);
    });
    it('There is a script element in the DOM', () => {
      let found = document.getElementById('test-acuant-sdk-script');
      expect(found).to.exist();
    });
    it('Has a global loadAcuantSdk object on the window', () => {
      expect(window.loadAcuantSdk).to.exist();
    });
    it('Calling loadAcuantSdk gives us AcuantJavascriptWebSdk in the global scope, but not as a prop of the window', () => {
      window.loadAcuantSdk();
      expect(AcuantJavascriptWebSdk).to.exist();
      expect(window.AcuantJavascriptWebSdk).to.not.exist();
    });
    after(() => {
      window = new JSDOM(
        '<!doctype html><html lang="en"><head><title>JSDOM</title></head></html>',
        {
          url: TEST_URL,
          runScripts: 'dangerously',
          resources: 'usable',
        },
      ).window;
      document = window.document;
    });
  });

  describe('DOM Loading 11.5.0', () => {
    before((done) => {
      let scriptEl = document.createElement('script');
      scriptEl.id = 'test-acuant-sdk-script';
      //scriptEl.textContent = scriptContent;
      scriptEl.onload = () => {
        done();
      };
      scriptEl.src = sdkPaths['11.5.0'];
      document.body.append(scriptEl);
    });
    it('There is a script element in the DOM', () => {
      let found = document.getElementById('test-acuant-sdk-script');
      expect(found).to.exist();
    });
    it('Has a global loadAcuantSdk object on the window', () => {
      expect(window.loadAcuantSdk).to.exist();
    });
    it('Calling loadAcuantSdk gives us AcuantJavascriptWebSdk in the window object', () => {
      window.loadAcuantSdk();
      expect(window.AcuantJavascriptWebSdk).to.exist();
    });
  });
});
