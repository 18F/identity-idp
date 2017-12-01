import { DelimitedTextFormatter } from 'field-kit';

/**
 * @const
 * @private
 */
const DIGITS_PATTERN = /^[a-zA-Z0-9]*$/;

/**
 * @extends DelimitedTextFormatter
 */
class PersonalKeyFormatter extends DelimitedTextFormatter {
  constructor() {
    super('-', true);
    this.maximumLength = 16 + 3;
  }

  /**
   * @param {number} index
   * @returns {boolean}
   */

  /* eslint-disable class-methods-use-this */
  hasDelimiterAtIndex(index) {
    return index === 4 || index === 9 || index === 14;
  }

  /**
   * Determines whether the given change should be allowed and, if so, whether
   * it should be altered.
   *
   * @param {TextFieldStateChange} change
   * @param {function(string)} error
   * @returns {boolean}
   */
  isChangeValid(change, error) {
    if (DIGITS_PATTERN.test(change.inserted.text)) {
      return super.isChangeValid(change, error);
    }

    return false;
  }
}

export default PersonalKeyFormatter;
