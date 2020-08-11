import React, { useContext } from 'react';
import render from '../../../support/render';
import DeviceContext from '@18f/identity-document-capture/context/device';

describe('document-capture/context/device', () => {
  const ContextValue = () => JSON.stringify(useContext(DeviceContext));

  it('defaults to an object shape of device supports', () => {
    const { container } = render(<ContextValue />);

    expect(container.textContent).to.equal('{"isMobile":false}');
  });
});
