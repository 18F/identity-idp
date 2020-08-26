import React from 'react';
import sinon from 'sinon';
import { fireEvent } from '@testing-library/react';
import useIfStillMounted from '@18f/identity-document-capture/hooks/use-if-still-mounted';
import render from '../../../support/render';

describe('document-capture/hooks/use-if-still-mounted', () => {
  function TestComponent({ callback }) {
    const ifStillMounted = useIfStillMounted();
    const fn = ifStillMounted(callback);

    return (
      <button type="button" onClick={() => setTimeout(fn, 0)}>
        trigger
      </button>
    );
  }

  it('returns function which executes callback if component is still mounted', (done) => {
    const spy = sinon.spy();

    const { getByText } = render(<TestComponent callback={spy} />);
    fireEvent.click(getByText('trigger'));

    setTimeout(() => {
      expect(spy.calledOnce).to.be.true();
      done();
    }, 0);
  });

  it('returns function which does not execute callback if component is unmounted', (done) => {
    const spy = sinon.spy();

    const { getByText, unmount } = render(<TestComponent callback={spy} />);
    fireEvent.click(getByText('trigger'));
    unmount();

    setTimeout(() => {
      expect(spy.called).to.be.false();
      done();
    }, 0);
  });
});
