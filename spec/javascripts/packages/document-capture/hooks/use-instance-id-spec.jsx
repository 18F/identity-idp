import { renderHook } from '@testing-library/react-hooks';
import useInstanceId from '@18f/identity-document-capture/hooks/use-instance-id';

describe('document-capture/hooks/use-instance-id', () => {
  it('returns a unique string id', () => {
    const { result: result1 } = renderHook(() => useInstanceId());
    const { result: result2 } = renderHook(() => useInstanceId());

    expect(result1.current).to.be.a('string');
    expect(result2.current).to.be.a('string');
    expect(result1.current).to.not.equal(result2.current);
  });
});
