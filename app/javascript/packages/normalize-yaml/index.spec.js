import normalize from './index.js';

describe('normalize', () => {
  it('applies smart quotes', async () => {
    const original = '---\na: \'<strong class="example...">Hello "world"...</strong>\'';
    const expected = '---\na: \'<strong class="example...">Hello “world”…</strong>\'\n';

    expect(await normalize(original)).to.equal(expected);
  });

  it('retains comments', async () => {
    const original = '---\n# Comment\na: true';
    const expected = '---\n# Comment\na: true\n';

    expect(await normalize(original)).to.equal(expected);
  });

  it('sorts keys', async () => {
    const original = '---\nmap:\n  b: false\n  a: true';
    const expected = '---\nmap:\n  a: true\n  b: false\n';

    expect(await normalize(original)).to.equal(expected);
  });

  it('collapses multiple spaces', async () => {
    const original = '---\nparagraph: Lorem ipsum.  Dolor sit  amet.';
    const expected = '---\nparagraph: Lorem ipsum. Dolor sit amet.\n';

    expect(await normalize(original)).to.equal(expected);
  });

  it('formats using prettier', async () => {
    const original = "---\nfoo:  'bar' ";
    const expected = '---\nfoo: "bar"\n';
    const prettierConfig = { singleQuote: false };

    expect(await normalize(original, { prettierConfig })).to.equal(expected);
  });

  it('allows leaving prose un-wrapped', async () => {
    const original =
      '---\nfoo: "some very long key that would normally go past 100 characters and get line wrapped but is going to stay on the same line"';
    const prettierConfig = { singleQuote: false, proseWrap: 'never' };

    expect((await normalize(original, { prettierConfig })).trimEnd()).to.equal(original);
  });

  it('allows formatting with excluded formatters', async () => {
    const original = '---\nmap:\n  b: ...\n  a: ...';
    const expected = '---\nmap:\n  a: ...\n  b: ...\n';

    expect(await normalize(original, { exclude: ['smartPunctuation'] })).to.equal(expected);
  });

  it('allows ignoring specific keys for sorting', async () => {
    const original = `---
a: 1
c: 3
d: 4
b: 2`;
    const expected = `---
a: 1
c: 3
b: 2
d: 4
`;

    expect(await normalize(original, { ignoreKeySort: ['c'] })).to.equal(expected);
  });
});
