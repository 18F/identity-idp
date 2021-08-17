import normalize from './index.js';

describe('normalize', () => {
  it('applies smart quotes', () => {
    const original = '---\na: \'<strong class="example...">Hello "world"...</strong>\'';
    const expected = '---\na: \'<strong class="example...">Hello “world”…</strong>\'\n';

    expect(normalize(original)).to.equal(expected);
  });

  it('retains comments', () => {
    const original = '---\n# Comment\na: true';
    const expected = '---\n# Comment\na: true\n';

    expect(normalize(original)).to.equal(expected);
  });

  it('sorts keys', () => {
    const original = '---\nmap:\n  b: false\n  a: true';
    const expected = '---\nmap:\n  a: true\n  b: false\n';

    expect(normalize(original)).to.equal(expected);
  });

  it('formats using prettier', () => {
    const original = "---\nfoo:  'bar' ";
    const expected = '---\nfoo: "bar"\n';
    const prettierConfig = { singleQuote: false };

    expect(normalize(original, { prettierConfig })).to.equal(expected);
  });

  it('allows formatting with excluded formatters', () => {
    const original = '---\nmap:\n  b: ...\n  a: ...';
    const expected = '---\nmap:\n  a: ...\n  b: ...\n';

    expect(normalize(original, { exclude: ['smartPunctuation'] })).to.equal(expected);
  });
});
