#!/usr/bin/env node

const { writeFileSync } = require('fs');
const browserslist = require('browserslist');

writeFileSync('./browsers.json', JSON.stringify(browserslist()));
