const chai = require('chai');
const dirtyChai = require('dirty-chai');
const { JSDOM } = require('jsdom');

chai.use(dirtyChai);
global.expect = chai.expect;

// Emulate a DOM, since many modules will assume the presence of these globals
// exist as a side effect of their import (focus-trap, classList.js, etc).
const dom = new JSDOM();
global.window = dom.window;
global.navigator = window.navigator;
global.document = window.document;
global.self = window;

beforeEach(() => {
  while (document.body.firstChild) {
    document.body.removeChild(document.body.firstChild);
  }
});

