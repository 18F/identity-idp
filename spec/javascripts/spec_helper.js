import chai from 'chai';
import dirtyChai from 'dirty-chai';
import { chaiConsoleSpy, useConsoleLogSpy } from './support/console';

chai.use(dirtyChai);
chai.use(chaiConsoleSpy);
global.expect = chai.expect;

// Emulate a DOM, since many modules will assume the presence of these globals exist as a side
// effect of their import (focus-trap, classList.js, etc). A URL is provided as a prerequisite to
// managing history API (pushState, etc).
const dom = new JSDOM('', { url: 'http://example.test' });
global.window = dom.window;
global.navigator = window.navigator;
global.document = window.document;
global.self = window;

beforeEach(() => {
  while (document.body.firstChild) {
    document.body.removeChild(document.body.firstChild);
  }
});
useConsoleLogSpy();
