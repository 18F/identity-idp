/**
 * Converts a base64-encoded string to an array buffer.
 *
 * @param base64 String to convert.
 * @return Converted string.
 */
export const base64ToArrayBuffer = (base64: string): ArrayBuffer =>
  Uint8Array.from(atob(base64), (c) => c.charCodeAt(0)).buffer;

/**
 * Converts an array buffer to a base64-encoded string.
 *
 * @param arrayBuffer ArrayBuffer to convert.
 * @return Converted string.
 */
export const arrayBufferToBase64 = (arrayBuffer: ArrayBuffer): string =>
  window.btoa(
    Array.from(new Uint8Array(arrayBuffer))
      .map((byte) => String.fromCharCode(byte))
      .join(''),
  );

/**
 * Given a number, returns the value represented as a byte array.
 *
 * @param long Number to convert.
 * @return Converted number.
 */
export const longToByteArray = (long: number): Uint8Array =>
  new Uint8Array(8).map(() => {
    const byte = long & 0xff; // eslint-disable-line no-bitwise
    long = (long - byte) / 256;
    return byte;
  });
