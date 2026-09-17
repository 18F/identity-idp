import {
  NDS_PHONE_GROUP_SELECTOR,
  getNdsPhoneGroupE164,
} from '@18f/identity-input-validation/nds-phone-group';

// Shows the "we couldn't match you to this number" warning on the NDS IdV
// phone page only while the typed number is one that already failed
// verification (mirrors idv-phone-alert.ts for the legacy lg-phone-input).
export function initialize(root: ParentNode = document) {
  const alertElement = root.querySelector<HTMLElement>('#phone-already-submitted-alert');
  const group = root.querySelector<HTMLElement>(NDS_PHONE_GROUP_SELECTOR);
  if (!alertElement || !group) {
    return;
  }

  const failedPhoneNumbers: string[] = JSON.parse(alertElement.dataset.failedPhoneNumbers || '[]');

  const sync = () => {
    const number = getNdsPhoneGroupE164(group);
    alertElement.hidden = !number || !failedPhoneNumbers.includes(number);
  };

  group.addEventListener('input', sync);
  group.addEventListener('change', sync);
}

if (process.env.NODE_ENV !== 'test') {
  initialize();
}
