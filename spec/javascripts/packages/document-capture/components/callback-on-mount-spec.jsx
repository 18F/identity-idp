import sinon from 'sinon';
import { render } from '@testing-library/react';
import CallbackOnMount from '@18f/identity-document-capture/components/callback-on-mount';

describe('document-capture/components/callback-on-mount', () => {
  it('calls callback once on mount', () => {
    const callback = sinon.spy();

    render(<CallbackOnMount onMount={callback} />);

    expect(callback.calledOnce).to.be.true();
  });

  it('renders children', () => {
    const { getByText } = render(<CallbackOnMount onMount={() => {}}>Children</CallbackOnMount>);

    expect(getByText('Children')).to.be.ok();
  });
});
