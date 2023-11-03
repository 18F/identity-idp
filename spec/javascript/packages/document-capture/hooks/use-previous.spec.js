import { renderHook } from '@testing-library/react';
import usePrevious from '@18f/identity-document-capture/hooks/use-previous';

describe('document-capture/hooks/use-previous', () => {
  it('returns undefined on first render', () => {
    const { result } = renderHook(({ value }) => usePrevious(value), {
      initialProps: { value: 10 },
    });

    expect(result.current).to.be.undefined();
  });

  it('returns previous value', () => {
    const { result, rerender } = renderHook(({ value }) => usePrevious(value), {
      initialProps: { value: 10 },
    });

    rerender({ value: 20 });

    expect(result.current).to.equal(10);
  });
});
