import useDefineProperty from './use-define-property';

describe('useDefineProperty', () => {
  const defineProperty = useDefineProperty();

  before(() => {
    (global as any).useDefineProperty = 10;
    defineProperty(global, 'useDefineProperty', { get: () => 20 });
  });

  after(() => {
    expect((global as any).useDefineProperty).to.equal(10);
    delete (global as any).useDefineProperty;
  });

  it('has property descriptor during spec', () => {
    expect((global as any).useDefineProperty).to.equal(20);
  });
});
