import sinon from 'sinon';
import { useObservableProperty } from '@18f/identity-document-capture/hooks/use-observable-property';
import { renderHook } from '@testing-library/react-hooks';

describe('document-capture/hooks/use-observable-property', () => {
  describe('useObservableProperty', () => {
    it('behaves like an object', () => {
      const object = {} as { key?: string };

      renderHook(() => useObservableProperty(object, 'key', () => {}));

      object.key = 'value';

      expect(object.key).to.equal('value');
    });

    it('calls the callback on changes, with the changed value', () => {
      const callback = sinon.spy();
      const object = {} as { key?: string };

      renderHook(() => useObservableProperty(object, 'key', callback));
      object.key = 'value';

      expect(callback).to.have.been.calledOnceWithExactly('value');
    });

    it('returns a cleanup function that removes the observer', () => {
      const object = {} as { key?: string };
      const callback = sinon.spy();
      const { unmount } = renderHook(() => useObservableProperty(object, 'key', callback));

      object.key = 'value';

      unmount();
      expect(object.key).to.equal('value');

      object.key = 'second_value';
      expect(object.key).to.equal('second_value');

      expect(callback).to.have.been.calledOnceWithExactly('value');
    });
  });
});
