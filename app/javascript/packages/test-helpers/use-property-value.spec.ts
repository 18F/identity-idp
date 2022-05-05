import usePropertyValue from './use-property-value';

describe('usePropertyValue', () => {
  context('value was a key in object, with value', () => {
    const key = `usePropertyValue1`;
    (global as any)[key] = 10;
    usePropertyValue(global as any, key, 20);

    after(() => {
      expect((global as any)[key]).to.equal(10);
      delete (global as any)[key];
    });

    it('has value during spec', () => {
      expect((global as any)[key]).to.equal(20);
    });
  });

  context('value was not a key in object', () => {
    const key = `usePropertyValue2`;
    usePropertyValue(global as any, key, true);

    after(() => {
      expect((key in global) as any).to.be.false();
    });

    it('unsets the key after the test', () => {});
  });

  context('value was a key in object, with an explicitly undefined value', () => {
    const key = `usePropertyValue3`;
    (global as any)[key] = undefined;
    usePropertyValue(global as any, key, true);

    after(() => {
      expect((key in global) as any).to.be.true();
      delete (global as any).baz;
    });

    it('does not unset the key after the test', () => {});
  });
});
