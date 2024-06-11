import sinon from 'sinon';
import { defineObservableProperty } from '@18f/identity-document-capture/higher-order/observable-property';

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
});
