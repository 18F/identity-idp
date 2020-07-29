import { useContext } from 'react';
import DeviceContext from '../context/device';

/**
 * Hook which returns true if device supports the given video facing mode, or false otherwise.
 *
 * @param {VideoFacingModeEnum} mode Mode to test.
 *
 * @return {boolean} Whether devicew supports video facing mode.
 */
function useDeviceHasVideoFacingMode(mode) {
  const { supports } = useContext(DeviceContext);
  return Boolean(supports.video.facingMode[mode]);
}

export default useDeviceHasVideoFacingMode;
