import { renderHook } from '@testing-library/react-hooks';
import useObjectMemo from './use-object-memo';

describe('useObjectMemo', () => {
  it('maintains reference over re-render for identical object values', () => {
    const { rerender, result } = renderHook(({ object }) => useObjectMemo(object), {
      initialProps: { object: { a: 1 } },
    });

    const { current: object1 } = result;

    rerender({ object: { a: 1 } });

    const { current: object2 } = result;

    expect(object1).to.equal(object2);
    expect(object1).to.deep.equal({ a: 1 });
  });

  it('updates reference when re-rendering with new values', () => {
    const { rerender, result } = renderHook(({ object }) => useObjectMemo(object), {
      initialProps: { object: { a: 1 } },
    });

    const { current: object1 } = result;
    expect(object1).to.deep.equal({ a: 1 });

    rerender({ object: { a: 2 } });

    const { current: object2 } = result;
    expect(object2).to.deep.equal({ a: 2 });

    expect(object1).to.not.equal(object2);
  });
});
