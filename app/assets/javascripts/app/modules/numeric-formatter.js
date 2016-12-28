import { Formatter } from 'field-kit';


const DIGITS_PATTERN = /^\d*$/;


class NumericFormatter extends Formatter {
  constructor() {
    super();
  }

  isChangeValid(change, error) {
    if (DIGITS_PATTERN.test(change.inserted.text)) {
      return super.isChangeValid(change, error);
    }
    return false;
  }
}


export default NumericFormatter;
