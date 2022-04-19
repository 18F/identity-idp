import sinon from 'sinon';
import { renderHook } from '@testing-library/react-hooks';
import useIfStillMounted from './use-if-still-mounted';

describe('document-capture/hooks/use-if-still-mounted', () => {
  it('returns function which executes callback if component is still mounted', () => {
    const spy = sinon.spy();
    const { result } = renderHook(() => useIfStillMounted());
    const ifStillMounted = result.current;
    const fn = ifStillMounted(spy);
    fn();
    expect(spy.calledOnce).to.be.true();
  });

  it('returns function which does not execute callback if component is unmounted', () => {
    const spy = sinon.spy();
    const { result, unmount } = renderHook(() => useIfStillMounted());
    const ifStillMounted = result.current;
    const fn = ifStillMounted(spy);
    unmount();
    fn();
    expect(spy.called).to.be.false();
  });
});
