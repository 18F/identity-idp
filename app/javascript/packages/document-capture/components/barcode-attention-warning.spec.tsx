import { render } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { useSandbox } from '@18f/identity-test-helpers';
import { t } from '@18f/identity-i18n';
import * as analytics from '@18f/identity-analytics';
import BarcodeAttentionWarning from './barcode-attention-warning';

describe('BarcodeAttentionWarning', () => {
  const sandbox = useSandbox();
  let form: HTMLFormElement;

  beforeEach(() => {
    form = document.createElement('form');
    form.className = 'js-document-capture-form';
    form.submit = sandbox.stub();
    document.body.appendChild(form);

    sandbox.stub(window, 'fetch').resolves();
    sandbox.stub(analytics, 'trackEvent');
  });

  afterEach(() => {
    window.onbeforeunload = null;
  });

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
    const onbeforeunload = sandbox.stub();
    window.onbeforeunload = onbeforeunload;

    const { getByRole } = render(<BarcodeAttentionWarning {...DEFAULT_PROPS} />);

    const continueButton = getByRole('button', { name: t('forms.buttons.continue') });

    await userEvent.click(continueButton);

    expect(form.submit).to.have.been.calledOnce();
    expect(onbeforeunload).not.to.have.been.called();
    expect(analytics.trackEvent).to.have.been.calledWith('IdV: barcode warning continue clicked');
  });

  it('lets the user dismiss to take new photos', async () => {
    const onDismiss = sandbox.stub();

    const { getByRole } = render(
      <BarcodeAttentionWarning {...DEFAULT_PROPS} onDismiss={onDismiss} />,
    );

    const dismissButton = getByRole('button', { name: t('doc_auth.buttons.add_new_photos') });

    await userEvent.click(dismissButton);

    expect(onDismiss).to.have.been.calledOnce();
    expect(analytics.trackEvent).to.have.been.calledWith(
      'IdV: barcode warning retake photos clicked',
    );
  });
});
