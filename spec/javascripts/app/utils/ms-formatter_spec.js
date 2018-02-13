import msFormatter from '../../../../app/javascript/app/utils/ms-formatter';

describe('#msFormatter', () => {
  it('formats milliseconds as X:XX', () => {
    const output = msFormatter(0);
    expect(output).to.equal('0:00');
  });

  it('adds a leading zero if seconds are fewer than 10', () => {
    const output = msFormatter(6000);
    expect(output).to.equal('0:06');
  });
});
