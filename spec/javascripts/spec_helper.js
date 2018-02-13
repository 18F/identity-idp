const chai = require('chai');
const dirtyChai = require('dirty-chai');

chai.use(dirtyChai);
global.expect = chai.expect;
