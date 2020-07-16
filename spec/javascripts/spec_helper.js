const chai = require('chai');
const dirtyChai = require('dirty-chai');

chai.use(dirtyChai);
global.expect = chai.expect;

// classList.js will throw an error when loaded into the test environment, since
// it assumes the presence of a `self` global. This shim is enough only to skip
// the polyfill. It's expected where a DOM is used that JSDOM will provide the
// Element#classList implementation.
//
// See: https://github.com/eligrey/classList.js/issues/48
// See: https://github.com/eligrey/classList.js/blob/ecb3305/classList.js#L14
global.self = global;
