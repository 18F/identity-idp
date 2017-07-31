import { PhoneFormatter } from 'field-kit';

class USPhoneFormatter extends PhoneFormatter {
  isChangeValid(change, error) {
    const match = change.proposed.text.match(/^\+(\d?)/);
    if (match && match[1] === '') {
      change.proposed.text = '+1';
      change.proposed.selectedRange.start = 4;
    } else if (match && match[1] !== '1') {
      return false;
    }
    return super.isChangeValid(change, error);
  }
}

export default USPhoneFormatter;
