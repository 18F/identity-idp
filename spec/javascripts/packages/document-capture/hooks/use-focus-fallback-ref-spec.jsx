import React, { createRef } from 'react';
import sinon from 'sinon';
import useFocusFallbackRef from '@18f/identity-document-capture/hooks/use-focus-fallback-ref';
import { render } from '../../../support/document-capture';

describe('document-capture/hooks/use-focus-fallback', () => {
  function ButtonWithFocusFallback({ fallbackRef }) {
    const ref = useFocusFallbackRef(fallbackRef);
    return (
      <button type="button" ref={ref}>
        Click me
      </button>
    );
  }

  it('shifts focus to fallback when unmounting while focused', () => {
    const fallbackRef = createRef();
    fallbackRef.current = { focus: sinon.stub() };
    const { getByText, unmount } = render(<ButtonWithFocusFallback fallbackRef={fallbackRef} />);

    const button = getByText('Click me');
    button.focus();
    unmount();

    expect(fallbackRef.current.focus.calledOnce).to.be.true();
  });

  it('does not shift focus to fallback when unmounted if not focused', () => {
    const fallbackRef = createRef();
    fallbackRef.current = { focus: sinon.stub() };
    const { unmount } = render(<ButtonWithFocusFallback fallbackRef={fallbackRef} />);

    unmount();

    expect(fallbackRef.current.focus.called).to.be.false();
  });
});
