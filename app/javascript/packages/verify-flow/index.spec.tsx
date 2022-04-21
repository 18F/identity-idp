import sinon from 'sinon';
import { render } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { VerifyFlow } from './index';

describe('VerifyFlow', () => {
  it('advances through flow to completion', async () => {
    const personalKey = '0000-0000-0000-0000';
    const onComplete = sinon.spy();

    const { getByRole } = render(
      <VerifyFlow
        appName="Example App"
        initialValues={{ personalKey }}
        basePath="/"
        onComplete={onComplete}
      />,
    );

    await userEvent.click(getByRole('button', { name: 'forms.buttons.continue' }));
    await userEvent.type(
      getByRole('textbox', { name: 'forms.personal_key.confirmation_label' }),
      personalKey,
    );
    await userEvent.keyboard('{Enter}');

    expect(onComplete).to.have.been.called();
  });
});
