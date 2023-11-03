import { useContext } from 'react';
import { renderHook } from '@testing-library/react';
import DeviceContext from '@18f/identity-document-capture/context/device';

describe('document-capture/context/device', () => {
  it('defaults to an object shape of device supports', () => {
    const { result } = renderHook(() => useContext(DeviceContext));

    expect(result.current).to.deep.equal({ isMobile: false });
  });
});
