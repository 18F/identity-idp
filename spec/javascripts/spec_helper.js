import { Crypto } from '@peculiar/webcrypto';
import chai from 'chai';
import dirtyChai from 'dirty-chai';
import sinonChai from 'sinon-chai';
import chaiAsPromised from 'chai-as-promised';
import { createDOM, useCleanDOM } from './support/dom';
import { chaiConsoleSpy, useConsoleLogSpy } from './support/console';
import { sinonChaiAsPromised } from './support/sinon';
import { createObjectURLAsDataURL } from './support/file';
import { useBrowserCompatibleEncrypt } from './support/crypto';

chai.use(sinonChai);
chai.use(chaiAsPromised);
chai.use(chaiConsoleSpy);
chai.use(sinonChaiAsPromised);
chai.use(dirtyChai);
global.expect = chai.expect;

// Emulate a DOM, since many modules will assume the presence of these globals exist as a side
// effect of their import (focus-trap, classList.js, etc). A URL is provided as a prerequisite to
// managing history API (pushState, etc).
const dom = createDOM();
global.window = dom.window;
global.window.fetch = () => Promise.reject(new Error('Fetch must be stubbed'));
global.window.crypto = new Crypto(); // In the future (Node >=15), use native webcrypto: https://nodejs.org/api/webcrypto.html
global.window.URL.createObjectURL = createObjectURLAsDataURL;
global.window.URL.revokeObjectURL = () => {};
Object.defineProperty(global.window.Image.prototype, 'src', {
  set() {
    this.onload();
  },
});
global.navigator = window.navigator;
global.document = window.document;
global.Document = window.Document;
global.Element = window.Element;
global.Node = window.Node;
global.getComputedStyle = window.getComputedStyle;
global.self = window;

useCleanDOM(dom);
useConsoleLogSpy();
useBrowserCompatibleEncrypt();
