import { Formatter } from 'field-kit';


const DIGITS_PATTERN = /^\d*$/;
const maxLength = 6;


class OtpCodeFormatter extends Formatter {
  constructor() {
    super();
    this.maximumLength = maxLength;
  }

  isChangeValid(change, error) {
    if (DIGITS_PATTERN.test(change.inserted.text)) {
      return super.isChangeValid(change, error);
    }
    return false;
  }
}


export default OtpCodeFormatter;
