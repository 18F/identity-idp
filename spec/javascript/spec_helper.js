import { webcrypto } from 'crypto';
import chai from 'chai';
import dirtyChai from 'dirty-chai';
import sinonChai from 'sinon-chai';
import chaiAsPromised from 'chai-as-promised';
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
global.jsdom = dom;
global.window = dom.window;
Object.assign(global.navigator, dom.window.navigator);
const windowGlobals = Object.fromEntries(
  Object.getOwnPropertyNames(window)
    .filter((key) => !(key in global))
    .map((key) => [key, window[key]]),
);
Object.assign(global, windowGlobals);
global.window.fetch = fetch;
global.fetch = global.window.fetch;
global.Event = global.window.Event;
global.CustomEvent = global.window.CustomEvent;
Object.defineProperty(global.window, 'crypto', { value: webcrypto });
global.window.URL.createObjectURL = createObjectURLAsDataURL;
global.window.URL.revokeObjectURL = () => {};
Object.defineProperty(global.window.Image.prototype, 'src', {
  set() {
    this.onload();
  },
});
global.navigator.sendBeacon = () => true;

// eslint-disable-next-line react-hooks/rules-of-hooks
useCleanDOM(dom);
// eslint-disable-next-line react-hooks/rules-of-hooks
useConsoleLogSpy();
