#!/usr/bin/env node
import { isAllSafe } from './index.js';

const patterns = process.argv.slice(2);
if (patterns.length) {
  isAllSafe(patterns).then((isSafe) => process.exit(isSafe ? 0 : 1));
} else {
  console.log('Usage: is-es5-safe <pattern>');
  process.exit(1);
}
