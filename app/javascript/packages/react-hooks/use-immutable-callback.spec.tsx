import sinon from 'sinon';
import { renderHook } from '@testing-library/react';
import useImmutableCallback from './use-immutable-callback';

describe('useImmutableCallback', () => {
  const callback1 = (_arg1: any, _arg2: any) => {};
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
    result.current(1, 2);

    expect(callback2).to.have.been.calledWith(1, 2);
  });
});
