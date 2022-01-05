import sinon from 'sinon';
import { renderHook } from '@testing-library/react-hooks';
import useCookie from '@18f/identity-document-capture/hooks/use-cookie';

describe('document-capture/hooks/use-cookie', () => {
  it('gives the current cookie value', () => {
    document.cookie = 'foo=bar';
    document.cookie = 'foo=baz';
    document.cookie = 'baz=qux';

    const { result } = renderHook(() => useCookie('foo'));

    const [getValue] = result.current;

    expect(getValue()).to.equal('baz');
  });

  it('sets a new cookie value', () => {
    const render = sinon.stub().callsFake(() => useCookie('foo'));
    const { result } = renderHook(render);

    const [getValue, setValue] = result.current;

    render.reset();
    setValue('bar');
    expect(render).to.have.been.called();

    expect(document.cookie).to.equal('foo=bar');
    expect(getValue()).to.equal('bar');
  });

  it('unsets a cookie value by null', () => {
    document.cookie = 'foo=bar';

    const render = sinon.stub().callsFake(() => useCookie('foo'));
    const { result } = renderHook(render);

    const [getValue, setValue] = result.current;

    render.reset();
    setValue(null);
    expect(render).to.have.been.called();

    expect(document.cookie).to.equal('');
    expect(getValue()).to.be.null();
  });
});
