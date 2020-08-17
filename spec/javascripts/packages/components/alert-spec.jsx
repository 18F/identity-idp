import React from 'react';
import { Alert } from '@18f/identity-components';
import render from '../../support/render';

describe('identity-components/alert', () => {
  it('should apply alert role', () => {
    const { getByRole } = render(<Alert type="warning">Uh oh!</Alert>);

    const alert = getByRole('alert');

    expect(alert).to.be.ok();
  });
});
