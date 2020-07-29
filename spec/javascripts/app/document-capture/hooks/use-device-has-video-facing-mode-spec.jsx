import React from 'react';
import render from '../../../support/render';
import DeviceContext from '../../../../../app/javascript/app/document-capture/context/device';
import useDeviceHasVideoFacingMode from '../../../../../app/javascript/app/document-capture/hooks/use-device-has-video-facing-mode';

describe('document-capture/hooks/use-device-has-video-facing-mode', () => {
  const DeviceSupports = ({ mode }) => String(useDeviceHasVideoFacingMode(mode));

  it('returns false for default context value', () => {
    const { container } = render(<DeviceSupports mode="environment" />);

    expect(container.textContent).to.equal('false');
  });

  it('returns false if the support is unset', () => {
    const { container } = render(
      <DeviceContext.Provider
        value={{ supports: { video: { facingMode: { environment: true } } } }}
      >
        <DeviceSupports mode="user" />
      </DeviceContext.Provider>,
    );

    expect(container.textContent).to.equal('false');
  });

  it('returns true if the support is explicitly true', () => {
    const { container } = render(
      <DeviceContext.Provider
        value={{ supports: { video: { facingMode: { environment: true } } } }}
      >
        <DeviceSupports mode="environment" />
      </DeviceContext.Provider>,
    );

    expect(container.textContent).to.equal('true');
  });
});
