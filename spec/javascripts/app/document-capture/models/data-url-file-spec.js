import DataURLFile from '../../../../../app/javascript/packages/document-capture/models/data-url-file';

describe('document-capture/models/data-url-file', () => {
  it('constructs with data', () => {
    const file = new DataURLFile('data:text/plain;base64,');

    expect(file.data).to.equal('data:text/plain;base64,');
    expect(file.name).to.be.undefined();
  });

  it('constructs with data and name', () => {
    const file = new DataURLFile('data:text/plain;base64,', 'demo.txt');

    expect(file.data).to.equal('data:text/plain;base64,');
    expect(file.name).to.equal('demo.txt');
  });

  it('serializes to data in JSONification', () => {
    const file = new DataURLFile('data:text/plain;base64,', 'demo.txt');

    expect(JSON.stringify(file)).to.equal('"data:text/plain;base64,"');
  });
});
