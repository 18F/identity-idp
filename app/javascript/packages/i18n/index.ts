interface PluralizedEntry {
  one: string;
  other: string;
}

type Entry = string | PluralizedEntry;
type Entries = Record<string, Entry>;
type Variables = Record<string, any>;

interface I18nOptions {
  strings?: Entries;
}

const hasOwn = (object: object, key: string): boolean =>
  Object.prototype.hasOwnProperty.call(object, key);

/**
 * Returns the pluralization object key corresponding to the given number.
 *
 * @param count Count.
 *
 * @return Pluralization key.
 */
const getPluralizationKey = (count?: number): keyof PluralizedEntry =>
  count === 1 ? 'one' : 'other';

/**
 * Returns an entry from locale data.
 *
 * @param entry Locale data.
 * @param count Pluralization count, if applicable.
 *
 * @return Entry string or object.
 */
const getEntry = (strings: Entries, key: string): Entry =>
  hasOwn(strings, key) ? strings[key] : key;

/**
 * Returns the resulting string from the given entry, incorporating pluralization if necessary.
 *
 * @param entry Entry string or object.
 * @param count Pluralization count, if applicable.
 *
 * @return Entry string.
 */
const getString = (entry: Entry, count?: number): string =>
  typeof entry === 'object' ? entry[getPluralizationKey(count)] : entry;

/**
 * Returns string with variable substitution.
 *
 * @param string Original string.
 * @param variables Variables to replace.
 *
 * @return String with variables substituted.
 */
export const replaceVariables = (string: string, variables: Variables): string =>
  string.replace(/%{(\w+)}/g, (match, key) => (hasOwn(variables, key) ? variables[key] : match));

class I18n {
  strings: Entries;

  constructor({ strings }: I18nOptions = {}) {
    this.strings = Object.assign(Object.create(null), strings);
    this.t = this.t.bind(this);
  }

  /**
   * Returns the translated string by the given key.
   *
   * @param key Key to retrieve.
   * @param variables Variables to substitute in string.
   *
   * @return Translated string.
   */
  t(key: string, variables: Variables = {}): string {
    const entry = getEntry(this.strings, key);
    const string = getString(entry, variables.count);
    return replaceVariables(string, variables);
  }
}

export { I18n };
