interface PluralizedEntry {
  one: string;
  other: string;
}

type Entry = string | string[] | PluralizedEntry;
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
const getPluralizationKey = (count: number): keyof PluralizedEntry =>
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
 * Returns true if the given entry is a pluralization entry, or false otherwise.
 *
 * @param entry Entry to test.
 *
 * @return Whether entry is a pluralization entry.
 */
const isPluralizedEntry = (entry: Entry): entry is PluralizedEntry =>
  typeof entry === 'object' && 'one' in entry;

/**
 * Returns true if the given entry is a string entry, or false otherwise.
 *
 * @param entry Entry to test.
 *
 * @return Whether entry is a string entry.
 */
const isStringEntry = (entry: Entry): entry is string => typeof entry === 'string';

/**
 * Returns the resulting string from the given entry, incorporating pluralization if necessary.
 *
 * @param entry Entry string or object.
 * @param count Pluralization count, if applicable.
 *
 * @return Entry string.
 */
function getString(entry: Entry, count?: number): string | string[] {
  if (isPluralizedEntry(entry)) {
    if (typeof count !== 'number') {
      throw new TypeError('Expected count for PluralizedEntry');
    }

    return entry[getPluralizationKey(count)];
  }

  return entry;
}

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
   * @param keyOrKeys Key or keys to retrieve.
   * @param variables Variables to substitute in string.
   *
   * @return Translated string.
   */
  t(keyOrKeys: string, variables?: Variables): string;
  t(keyOrKeys: string[], variables?: Variables): string[];
  t(keyOrKeys: string | string[], variables: Variables = {}): string | string[] {
    const isSingular = !Array.isArray(keyOrKeys);
    const keys: string[] = isSingular ? [keyOrKeys] : keyOrKeys;
    const entries = keys.map((key) => getEntry(this.strings, key));
    const strings = entries
      .map((entry) => (isPluralizedEntry(entry) ? getString(entry, variables?.count) : entry))
      .map((entry) => (isStringEntry(entry) ? replaceVariables(entry, variables) : entry));

    return isSingular ? strings[0] : strings.flat();
  }
}

// eslint-disable-next-line no-underscore-dangle
const i18n = new I18n({ strings: globalThis._locale_data });
const { t } = i18n;

export { I18n, i18n, t };
