import React from 'react';
import sinon from 'sinon';
import CallbackOnMount from '@18f/identity-document-capture/components/callback-on-mount';
import render from '../../../support/render';

describe('document-capture/components/callback-on-mount', () => {
  it('calls callback once on mount', () => {
    const callback = sinon.spy();

    render(<CallbackOnMount onMount={callback} />);

    expect(callback.calledOnce).to.be.true();
  });
});
