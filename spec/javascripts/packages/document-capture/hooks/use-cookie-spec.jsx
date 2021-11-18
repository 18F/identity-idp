import { renderHook } from '@testing-library/react-hooks';
import useCookie from '@18f/identity-document-capture/hooks/use-cookie';

describe('document-capture/hooks/use-cookie', () => {
  it('gives the current cookie value', () => {
    document.cookie = 'foo=bar';
    document.cookie = 'foo=baz';
    document.cookie = 'baz=qux';

    const { result } = renderHook(() => useCookie('foo'));

    const [value] = result.current;

    expect(value).to.equal('baz');
  });

  it('does not interfere with default cookie setting behavior', () => {
    renderHook(() => useCookie('foo'));

    document.cookie = 'foo=bar';

    expect(document.cookie).to.equal('foo=bar');
  });

  it('sets a new cookie value', () => {
    const { result } = renderHook(() => useCookie('foo'));

    const [, setValue] = result.current;

    setValue('bar');

    const [value] = result.current;

    expect(document.cookie).to.equal('foo=bar');
    expect(value).to.equal('bar');
  });

  it('unsets a cookie value by null', () => {
    document.cookie = 'foo=bar';

    const { result } = renderHook(() => useCookie('foo'));

    const [, setValue] = result.current;

    setValue(null);

    const [value] = result.current;

    expect(document.cookie).to.equal('');
    expect(value).to.be.null();
  });
});
