import sinon from 'sinon';
import {
  defineObservableProperty,
  stopObservingProperty,
} from '@18f/identity-document-capture/higher-order/observable-property';

describe('document-capture/higher-order/observable-property', () => {
  describe('defineObservableProperty', () => {
    it('behaves like an object', () => {
      const object = {};
      defineObservableProperty(object, 'key', () => {});
      object.key = 'value';

      expect(object.key).to.equal('value');
    });

    it('calls the callback on changes, with the changed value', () => {
      const callback = sinon.spy();
      const object = {};
      defineObservableProperty(object, 'key', callback);
      object.key = 'value';

      expect(callback).to.have.been.calledOnceWithExactly('value');
    });
  });

  describe('stopObservingProperty', () => {
    it('removes the defined property and set the last value as a plain value', () => {
      const object = {};
      const callback = sinon.spy();
      defineObservableProperty(object, 'key', callback);

      object.key = 'value';

      stopObservingProperty(object, 'key');
      expect(object.key).to.equal('value');

      object.key = 'second_value';
      expect(object.key).to.equal('second_value');

      expect(callback).to.have.been.calledOnceWithExactly('value');
    });
  });
});
