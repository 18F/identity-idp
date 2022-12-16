import { webcrypto } from 'crypto';
import chai from 'chai';
import dirtyChai from 'dirty-chai';
import sinonChai from 'sinon-chai';
import chaiAsPromised from 'chai-as-promised';
import { Response } from 'whatwg-fetch';
import { createDOM, useCleanDOM } from './support/dom';
import { chaiConsoleSpy, useConsoleLogSpy } from './support/console';
import { sinonChaiAsPromised } from './support/sinon';
import { createObjectURLAsDataURL } from './support/file';

chai.use(sinonChai);
chai.use(chaiAsPromised);
chai.use(chaiConsoleSpy);
chai.use(sinonChaiAsPromised);
chai.use(dirtyChai);
global.expect = chai.expect;

// Emulate a DOM, since many modules will assume the presence of these globals exist as a side
// effect of their import.
const dom = createDOM();
global.window = dom.window;
const windowGlobals = Object.fromEntries(
  Object.getOwnPropertyNames(window)
    .filter((key) => !(key in global))
    .map((key) => [key, window[key]]),
);
Object.assign(global, windowGlobals);
global.window.fetch = () => Promise.reject(new Error('Fetch must be stubbed'));
Object.defineProperty(global.window, 'crypto', { value: webcrypto });
global.window.URL.createObjectURL = createObjectURLAsDataURL;
global.window.URL.revokeObjectURL = () => {};
Object.defineProperty(global.window.Image.prototype, 'src', {
  set() {
    this.onload();
  },
});
global.window.Response = Response;

useCleanDOM(dom);
useConsoleLogSpy();

// Remove after upgrading to React 18
// See: https://github.com/facebook/react/issues/20756#issuecomment-780945678
delete global.MessageChannel;
