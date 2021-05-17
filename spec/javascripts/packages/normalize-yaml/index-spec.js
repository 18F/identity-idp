import normalize from '@18f/identity-normalize-yaml';

describe('normalize', () => {
  it('applies smart quotes', () => {
    const original = '---\na: \'<strong class="example">Hello "world"...</strong>\'';
    const expected = '---\na: \'<strong class="example">Hello “world”…</strong>\'';

    expect(normalize(original)).to.equal(expected);
  });

  it('sorts keys', () => {
    const original = '---\nb: false\na: true';
    const expected = '---\na: true\nb: false';

    expect(normalize(original)).to.equal(expected);
  });

  it('formats using prettier', () => {
    const original = '---\nfoo:  "bar" ';
    const expected = "---\nfoo: 'bar'";
    const prettierConfig = { singleQuote: true };

    expect(normalize(original, prettierConfig)).to.equal(expected);
  });
});
