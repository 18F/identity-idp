import sinon from 'sinon';
import { renderHook } from '@testing-library/react-hooks';
import useDidUpdateEffect from './use-did-update-effect';

describe('document-capture/hooks/use-did-update-effect', () => {
  context('no dependencies', () => {
    it('does not call callback during mount', () => {
      const callback = sinon.spy();
      renderHook(() => useDidUpdateEffect(callback));

      expect(callback.called).to.be.false();
    });

    it('calls callback after update', () => {
      const callback = sinon.spy();
      const { rerender } = renderHook(() => useDidUpdateEffect(callback));

      rerender();

      expect(callback.calledOnce).to.be.true();
    });
  });

  context('dependencies', () => {
    it('does not call callback during mount', () => {
      const callback = sinon.spy();
      renderHook(({ dep }) => useDidUpdateEffect(callback, [dep]), { initialProps: { dep: 'a' } });

      expect(callback.called).to.be.false();
    });

    it('does not call callback after update if deps are same', () => {
      const callback = sinon.spy();
      const { rerender } = renderHook(({ dep }) => useDidUpdateEffect(callback, [dep]), {
        initialProps: { dep: 'a' },
      });

      rerender({ dep: 'a' });

      expect(callback.called).to.be.false();
    });

    it('calls callback after update if deps change', () => {
      const callback = sinon.spy();
      const { rerender } = renderHook(({ dep }) => useDidUpdateEffect(callback, [dep]), {
        initialProps: { dep: 'a' },
      });

      rerender({ dep: 'b' });

      expect(callback.calledOnce).to.be.true();
    });
  });
});
