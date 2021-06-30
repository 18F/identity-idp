import * as exported from '@18f/identity-document-capture/context';

describe('document-capture/context/index', () => {
  it('assigns display name for each exported context', () => {
    Object.entries(exported)
      .filter(([exportedName]) => exportedName.endsWith('Context'))
      .forEach(([, Context]) => expect(Context).to.have.property('displayName'));
  });
});
