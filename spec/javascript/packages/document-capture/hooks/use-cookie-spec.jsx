import sinon from 'sinon';
import { renderHook } from '@testing-library/react';
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

  it('sets a new cookie value', () => {
    const render = sinon.stub().callsFake(() => useCookie('foo'));
    const { result } = renderHook(render);

    const [, setValue] = result.current;

    render.resetHistory();
    setValue('bar');
    expect(render).to.have.been.calledOnce();

    const [value] = result.current;

    expect(document.cookie).to.equal('foo=bar');
    expect(value).to.equal('bar');
  });

  it('unsets a cookie value by null', () => {
    document.cookie = 'foo=bar';

    const render = sinon.stub().callsFake(() => useCookie('foo'));
    const { result } = renderHook(render);

    const [, setValue] = result.current;

    render.resetHistory();
    setValue(null);
    expect(render).to.have.been.calledOnce();

    const [value] = result.current;

    expect(document.cookie).to.equal('');
    expect(value).to.be.null();
  });

  it('returns the same updated value between instances', () => {
    const render1 = sinon.stub().callsFake(() => useCookie('foo'));
    const render2 = sinon.stub().callsFake(() => useCookie('foo'));
    const { result: result1 } = renderHook(render1);
    const { result: result2 } = renderHook(render2);

    const [, setValue] = result1.current;

    render1.resetHistory();
    render2.resetHistory();
    setValue('bar');
    expect(render1).to.have.been.calledOnce();
    expect(render2).to.have.been.calledOnce();

    const [value1] = result1.current;
    const [value2] = result2.current;

    expect(value1).to.equal('bar');
    expect(value2).to.equal('bar');
  });

  it('refreshes a cookie value', () => {
    const render = sinon.stub().callsFake(() => useCookie('foo'));
    const { result } = renderHook(render);

    document.cookie = 'foo=bar';

    const [, , refreshValue] = result.current;

    render.resetHistory();
    refreshValue();
    expect(render).to.have.been.calledOnce();

    const [value] = result.current;

    expect(value).to.equal('bar');
  });
});
