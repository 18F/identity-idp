/**
 * Returns string with variable substitution.
 *
 * @param {string} string Original string.
 * @param {Record<string,string>} variables Variables to replace.
 *
 * @return {string} String with variables substituted.
 */
export function replaceVariables(string, variables) {
  return Object.keys(variables).reduce(
    (result, key) => result.replace(new RegExp(`%{${key}}`, 'g'), variables[key]),
    string,
  );
}

class I18n {
  /**
   * @param {{ strings?: Record<string, string> }=} options
   */
  constructor({ strings } = {}) {
    /** @type {Record<string, string>} */
    this.strings = Object.assign(Object.create(null), strings);
    this.t = this.t.bind(this);
  }

  /**
   * Returns the translated string by the given key.
   *
   * @param {string} key Key to retrieve.
   * @param {Record<string,string>=} variables Variables to substitute in string.
   *
   * @return {string} Translated string.
   */
  t(key, variables) {
    const string = key in this.strings ? this.strings[key] : key;
    return variables ? replaceVariables(string, variables) : string;
  }
}

export { I18n };
