import { replaceInHTMLContent, ellipses } from './smart-punctuation.js';

describe('replaceInHTMLContent', () => {
  it('replaces in html content', () => {
    const string = '<div>This is a failure</div>';
    const result = replaceInHTMLContent(string, (match) => match.replace('failure', 'success'));
    const expected = '<div>This is a success</div>';

    expect(result).to.equal(expected);
  });

  it('does not replace in html tags', () => {
    const string = '<div data-div-type="div">div<div>div</div>div</div>';
    const result = replaceInHTMLContent(string, (match) => match.replace('div', ''));
    const expected = '<div data-div-type="div"><div></div></div>';

    expect(result).to.equal(expected);
  });
});

describe('ellipses', () => {
  it('replaces all instances of dots', () => {
    const string = 'You must first... before you can...';
    const result = ellipses(string);
    const expected = 'You must first… before you can…';

    expect(result).to.equal(expected);
  });
});
