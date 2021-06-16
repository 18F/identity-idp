import sinon from 'sinon';
import { renderHook } from '@testing-library/react-hooks';
import useImmutableCallback from '@18f/identity-document-capture/hooks/use-immutable-callback';

describe('document-capture/hooks/use-immutable-callback', () => {
  const callback1 = () => {};
  const callback2 = sinon.stub().callsFake(() => {});

  it('maintains a consistent reference', () => {
    const { rerender, result } = renderHook(({ fn }) => useImmutableCallback(fn), {
      initialProps: { fn: callback1 },
    });

    const { current: renderedCallback1 } = result;
    rerender({ fn: callback2 });
    const { current: renderedCallback2 } = result;

    expect(renderedCallback1).to.equal(renderedCallback2);
  });

  it('invokes the latest reference of callback', () => {
    const { rerender, result } = renderHook(({ fn }) => useImmutableCallback(fn), {
      initialProps: { fn: callback1 },
    });

    rerender({ fn: callback2 });
    const args = [1, 2];
    result.current(...args);

    expect(callback2).to.have.been.calledWith(...args);
  });
});
