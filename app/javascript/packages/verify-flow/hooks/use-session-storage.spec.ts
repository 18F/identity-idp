import sinon from 'sinon';
import type { SinonStub } from 'sinon';
import { act, renderHook } from '@testing-library/react-hooks';
import { useDefineProperty } from '@18f/identity-test-helpers';
import useSessionStorage from './use-session-storage';

const TEST_KEY = 'key';

describe('useSessionStorage', () => {
  const defineProperty = useDefineProperty();

  beforeEach(() => {
    defineProperty(global, 'sessionStorage', {
      value: {
        getItem: sinon.stub(),
        setItem: sinon.stub(),
        removeItem: sinon.stub(),
      },
    });
  });

  afterEach(() => {
    sessionStorage.removeItem(TEST_KEY);
  });

  it('returns null for a value not in storage', () => {
    (sessionStorage.getItem as SinonStub).withArgs(TEST_KEY).returns(null);

    const { result } = renderHook(() => useSessionStorage(TEST_KEY));
    const [value, setValue] = result.current;

    expect(value).to.be.null();
    expect(setValue).to.be.a('function');
    expect(sessionStorage.setItem).not.to.have.been.called();
  });

  it('returns a value from storage', () => {
    (sessionStorage.getItem as SinonStub).withArgs(TEST_KEY).returns('value');

    const { result } = renderHook(() => useSessionStorage(TEST_KEY));
    const [value, setValue] = result.current;

    expect(value).to.equal('value');
    expect(setValue).to.be.a('function');
    expect(sessionStorage.setItem).not.to.have.been.called();
  });

  it('sets a string value into storage', () => {
    const { result } = renderHook(() => useSessionStorage(TEST_KEY));
    const [, setValue] = result.current;
    act(() => setValue('value'));

    expect(sessionStorage.setItem).to.have.been.calledWith(TEST_KEY, 'value');
  });

  it('unsets storage when given a null value', () => {
    const { result } = renderHook(() => useSessionStorage(TEST_KEY));
    const [, setValue] = result.current;
    act(() => setValue(null));

    expect(sessionStorage.removeItem).to.have.been.calledWith(TEST_KEY);
  });
});
