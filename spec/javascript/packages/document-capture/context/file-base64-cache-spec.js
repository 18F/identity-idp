import { useContext } from 'react';
import { renderHook } from '@testing-library/react';
import FileBase64Cache from '@18f/identity-document-capture/context/file-base64-cache';

describe('document-capture/context/file-base64-cache', () => {
  it('defaults to WeakMap', () => {
    const { result } = renderHook(() => useContext(FileBase64Cache));

    expect(result.current).to.be.instanceof(WeakMap);
  });
});
