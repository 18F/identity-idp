import usePropertyValue from './use-property-value';

describe('usePropertyValue', () => {
  (global as any).foo = 10;
  usePropertyValue(global as any, 'foo', 20);

  after(() => {
    expect((global as any).foo).to.equal(10);
    delete (global as any).foo;
  });

  it('has value during spec', () => {
    expect((global as any).foo).to.equal(20);
  });
});
