import type { expect as _expect } from 'chai';
import type { JSDOM } from 'jsdom';

declare global {
  const expect: typeof _expect;

  const jsdom: JSDOM;
}
