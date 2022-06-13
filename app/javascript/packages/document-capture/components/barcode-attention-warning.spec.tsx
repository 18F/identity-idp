import sinon from 'sinon';
import { render } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { useDefineProperty } from '@18f/identity-test-helpers';
import { t } from '@18f/identity-i18n';
import BarcodeAttentionWarning from './barcode-attention-warning';

describe('BarcodeAttentionWarning', () => {
  const defineProperty = useDefineProperty();

  const DEFAULT_PROPS = {
    onDismiss() {},
    pii: { first_name: 'Jane', last_name: 'Smith', dob: '1938-10-06' },
  };

  it('prompts the user to confirm the given PII', () => {
    const { getAllByRole } = render(<BarcodeAttentionWarning {...DEFAULT_PROPS} />);

    const items = getAllByRole('definition');

    expect(items.map((node) => node.textContent)).to.include.all.members([
      'Jane',
      'Smith',
      '1938-10-06',
    ]);
  });

  it('allows the user to continue to the next step', async () => {
    const onbeforeunload = sinon.stub();
    const reload = sinon.stub().callsFake(() => window.onbeforeunload?.(new CustomEvent('unload')));
    defineProperty(window, 'location', { value: { reload } });
    window.onbeforeunload = onbeforeunload;

    const { getByRole } = render(<BarcodeAttentionWarning {...DEFAULT_PROPS} />);

    const continueButton = getByRole('button', { name: t('forms.buttons.continue') });

    await userEvent.click(continueButton);

    expect(reload).to.have.been.calledOnce();
    expect(onbeforeunload).not.to.have.been.called();
  });

  it('lets the user dismiss to take new photos', async () => {
    const onDismiss = sinon.stub();

    const { getByRole } = render(
      <BarcodeAttentionWarning {...DEFAULT_PROPS} onDismiss={onDismiss} />,
    );

    const dismissButton = getByRole('button', { name: t('doc_auth.buttons.add_new_photos') });

    await userEvent.click(dismissButton);

    expect(onDismiss).to.have.been.calledOnce();
  });
});
