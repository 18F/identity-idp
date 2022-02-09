import msFormatter from '../../../../app/javascript/app/utils/ms-formatter';

describe('#msFormatter', () => {
  it('formats milliseconds as 0 minutes and 0 seconds)', () => {
    const output = msFormatter(0);
    expect(output).to.equal('0 minutes and 0 seconds');
  });

  it('adds a leading zero if seconds are fewer than 10', () => {
    const output = msFormatter(6000);
    expect(output).to.equal('0 minutes and 6 seconds');
  });

  it('adds a leading zero to minutes if minutes are fewer than 10 but greater than 0', () => {
    const output = msFormatter(300000);
    expect(output).to.equal('5 minutes and 0 seconds');
  });
});
