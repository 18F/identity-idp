import React, { useEffect } from 'react';
import sinon from 'sinon';
import { UploadContextProvider } from '@18f/identity-document-capture';
import withBackgroundEncryptedUpload from '@18f/identity-document-capture/higher-order/with-background-encrypted-upload';
import { useSandbox } from '../../../support/sinon';
import render from '../../../support/render';

describe('withBackgroundEncryptedUpload', () => {
  const sandbox = useSandbox();

  const Component = withBackgroundEncryptedUpload(({ onChange }) => {
    useEffect(() => {
      onChange({ foo: 'bar', baz: 'quux' });
    }, []);

    return null;
  });

  it('intercepts onChange to include background uploads', async () => {
    const onChange = sinon.spy();
    sandbox.stub(window, 'fetch').callsFake(() => Promise.resolve({}));
    render(
      <UploadContextProvider backgroundUploadURLs={{ foo: 'about:blank' }}>
        <Component onChange={onChange} />)
      </UploadContextProvider>,
    );

    expect(onChange.calledOnce).to.be.true();
    const patch = onChange.getCall(0).args[0];
    expect(patch).to.have.keys(['foo', 'baz', 'fooBackgroundUpload']);
    expect(patch.foo).to.equal('bar');
    expect(patch.baz).to.equal('quux');
    expect(patch.fooBackgroundUpload).to.be.an.instanceOf(Promise);
    expect(window.fetch.calledOnce).to.be.true();
    expect(window.fetch.getCall(0).args).to.deep.equal([
      'about:blank',
      {
        method: 'POST',
        body: 'bar',
      },
    ]);
    expect(await patch.fooBackgroundUpload).to.be.undefined();
  });
});
