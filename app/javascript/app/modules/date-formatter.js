import { DelimitedTextFormatter } from 'field-kit';

/**
 * @extends DelimitedTextFormatter
 */
class DateFormatter extends DelimitedTextFormatter {
  constructor() {
    super('/');
    this.maximumLength = 10;
  }

  /**
   * @param {number} index
   * @returns {boolean}
   */

  /* eslint-disable class-methods-use-this */
  hasDelimiterAtIndex(index) {
    return index === 2 || index === 5;
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
    if (!error) { error = function() {}; } // eslint-disable-line no-param-reassign

    const isBackspace = change.proposed.text.length < change.current.text.length;
    let newText = change.proposed.text;

    if (change.inserted.text === this.delimiter && change.current.text === '1') {
      newText = `01${this.delimiter}`;
    } else if (change.inserted.text === this.delimiter && /^(\d{2})(.)(\d)(.)$/.test(newText)) {
      const lastChar = newText.substr(newText.length - 2);
      newText = `${newText.slice(0, -2)}0${lastChar}`;
    } else if (change.inserted.text.length > 0 && !/^\d$/.test(change.inserted.text)) {
      error('date-formatter.only-digits-allowed');
      return false;
    } else {
      if (isBackspace) {
        if (change.deleted.text === this.delimiter) {
          newText = newText.slice(0, -1);
        }
        if (newText === '0') {
          newText = '';
        }
        if (/^(\d{2})(.)(0)$/.test(newText)) {
          newText = newText.slice(0, -2);
        }
      }

      // prepend month starting with 2-9 with a 0
      if (/^[2-9]$/.test(newText)) {
        newText = `0${newText}`;
      }

      // prepend day starting with 4-9 with a 0
      if (/^(\d{2})(.)([4-9])$/.test(newText)) {
        newText = `${newText.slice(0, -1)}0${change.inserted.text}`;
      }

      // don't allow month over 12
      if (/^1[3-9]$/.test(newText)) {
        error('date-formatter.invalid-month');
        return false;
      }

      // don't allow day over 31
      if (/^(\d{2})(.)(3[2-9])$/.test(newText)) {
        error('date-formatter.invalid-day');
        return false;
      }

      // don't allow 00 as day
      if (newText === '00') {
        error('date-formatter.invalid-month');
        return false;
      }

      // don't allow 00 as month
      if (/^(\d{2})(.)(00)$/.test(newText)) {
        error('date-formatter.invalid-month');
        return false;
      }

      // add delimiter after valid month
      if (/^(0[1-9]|1[0-2])$/.test(newText)) {
        newText += this.delimiter;
      }

      // add delimiter after valid month and day
      if (/^(\d{2})(.)(\d{2})$/.test(newText)) {
        newText += this.delimiter;
      }

      // don't allow year to start with 0 or 3+
      if (/^(\d{2})(.)(\d{2})(.)((0|[3-9]))$/.test(newText)) {
        error('date-formatter.invalid-year');
        return false;
      }

      const match = newText.match(/^(\d{2})(.)(\d{2})(.)(\d{4}).*$/);
      if (match && (match[2] === this.delimiter) && (match[4] === this.delimiter)) {
        newText = match[1] + this.delimiter + match[3] + this.delimiter + match[5];
      }
    }

    /* eslint-disable no-param-reassign */
    change.proposed.text = newText;
    change.proposed.selectedRange = { start: newText.length, length: 0 };
    /* eslint-enable no-param-reassign */

    return true;
  }
}

export default DateFormatter;
