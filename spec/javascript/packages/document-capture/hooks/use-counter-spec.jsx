import { act } from 'react-test-renderer';
import { renderHook } from '@testing-library/react-hooks';
import useCounter from '@18f/identity-document-capture/hooks/use-counter';

describe('document-capture/hooks/use-counter', () => {
  it('defaults to 0', () => {
    const { result } = renderHook(() => useCounter());

    const [count] = result.current;

    expect(count).to.be.equal(0);
  });

  it('accepts optional initial count', () => {
    const { result } = renderHook(() => useCounter(1));

    const [count] = result.current;

    expect(count).to.be.equal(1);
  });

  it('increments by one', () => {
    const { result } = renderHook(() => useCounter());

    const [, incrementCount] = result.current;

    act(incrementCount);

    const [count] = result.current;

    expect(count).to.equal(1);
  });

  it('can be reset', () => {
    const { result } = renderHook(() => useCounter());

    const [, incrementCount, resetCount] = result.current;

    act(incrementCount);
    act(resetCount);

    const [count] = result.current;

    expect(count).to.equal(0);
  });
});
