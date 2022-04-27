import usePropertyValue from './use-property-value';

describe('usePropertyValue', () => {
  (global as any).usePropertyValue = 10;
  usePropertyValue(global as any, 'usePropertyValue', 20);

  after(() => {
    expect((global as any).usePropertyValue).to.equal(10);
    delete (global as any).usePropertyValue;
  });

  it('has value during spec', () => {
    expect((global as any).usePropertyValue).to.equal(20);
  });
});
