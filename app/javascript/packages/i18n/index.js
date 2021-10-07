const hasOwn = (object, key) => Object.prototype.hasOwnProperty.call(object, key);

/**
 * Returns string with variable substitution.
 *
 * @param {string} string Original string.
 * @param {Record<string,string>} variables Variables to replace.
 *
 * @return {string} String with variables substituted.
 */
export const replaceVariables = (string, variables) =>
  string.replace(/%{(\w+)}/g, (match, key) => (hasOwn(variables, key) ? variables[key] : match));

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
