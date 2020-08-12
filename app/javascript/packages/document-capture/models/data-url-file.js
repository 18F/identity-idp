/**
 * Container class representation for a file, to represent both its name and data URL while in
 * memory, and to serialize only as its data URL string.
 */
class DataURLFile {
  /**
   * Constructs a new DataURLFile object.
   *
   * @param {string}  data Data URL for file.
   * @param {string=} name Optional name.
   */
  constructor(data, name) {
    this.data = data;
    this.name = name;
  }

  /**
   * Used to control the JSON serialization behavior to serialize as the data URL string.
   *
   * @see https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/JSON/stringify#toJSON_behavior
   *
   * @return {string} Data URL.
   */
  toJSON() {
    return this.data;
  }
}

export default DataURLFile;
