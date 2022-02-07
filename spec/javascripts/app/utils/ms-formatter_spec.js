import msFormatter from '../../../../app/javascript/app/utils/ms-formatter';

describe('#msFormatter', () => {
  it('formats milliseconds as XX:XX)', () => {
    const output = msFormatter(0);
    expect(output).to.equal('00:00');
  });

  it('formats milliseconds as XX:XX:XX for screen readers', () => {
    const output = msFormatter(0, true);
    expect(output).to.equal('00:00:00');
  });

  it('adds a leading zero if seconds are fewer than 10', () => {
    const output = msFormatter(6000);
    expect(output).to.equal('00:06');
  });

  it('adds a leading zero to minutes if minutes are fewer than 10 but greater than 0', () => {
    const output = msFormatter(300000);
    expect(output).to.equal('05:00');
  });

  it('adds a leading zero if seconds are fewer than 10 for screen readers', () => {
    const output = msFormatter(6000, true);
    expect(output).to.equal('00:00:06');
  });

  it('adds a leading zero if to minutes if munutes are fewer than 10  but greater than 0 for screen readers', () => {
    const output = msFormatter(300000, true);
    expect(output).to.equal('00:05:00');
  });
});
