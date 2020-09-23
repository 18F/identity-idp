import { useContext } from 'react';
import { renderHook } from '@testing-library/react-hooks';
import AssetContext from '@18f/identity-document-capture/context/asset';

describe('document-capture/context/asset', () => {
  it('defaults to empty object', () => {
    const { result } = renderHook(() => useContext(AssetContext));

    expect(result.current).to.deep.equal({});
  });
});
