//= require support/sinon
//= require support/chai
const dirtyChai = require('dirty-chai');
chai.use(dirtyChai);
// PhantomJS (Teaspoons default driver) doesn't have support for
// Function.prototype.bind, which has caused confusion.

// Use this polyfill to avoid the confusion.
//= require support/phantomjs-shims
window.expect = chai.expect;
