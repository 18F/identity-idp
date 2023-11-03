import { renderHook } from '@testing-library/react';
import useInstanceId from './use-instance-id';

describe('useInstanceId', () => {
  it('returns a unique string id', () => {
    const { result: result1 } = renderHook(() => useInstanceId());
    const { result: result2 } = renderHook(() => useInstanceId());

    expect(result1.current).to.be.a('string');
    expect(result2.current).to.be.a('string');
    expect(result1.current).to.not.equal(result2.current);
  });
});
