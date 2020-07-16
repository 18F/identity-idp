import { JSDOM } from 'jsdom';

export function useDOM(initialHTML) {
  before(() => {
    const dom = new JSDOM(initialHTML);
    global.window = dom.window;
    global.document = global.window.document;
  });

  beforeEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  after(() => {
    delete global.window;
    delete global.document;
  });
}
