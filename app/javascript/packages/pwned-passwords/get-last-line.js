import { open } from 'node:fs/promises';

/**
 * Returns a promise resolving to the last line of the given file.
 *
 * @param {string} path File path to read.
 *
 * @return {Promise<string | undefined>}
 */
async function getLastLine(path) {
  /** @type {import('fs/promises').FileHandle} */
  let file;
  try {
    file = await open(path);
  } catch {
    return;
  }

  const { size } = await file.stat();

  let data = '';
  const readLength = 64;
  for (
    let position = size - readLength;
    position >= 0;
    position -= Math.min(position, readLength)
  ) {
    // eslint-disable-next-line no-await-in-loop
    const { buffer } = await file.read({ position, length: readLength });
    data = buffer.toString() + data;
    const parts = data.split('\n');
    if (parts.length > 1) {
      // eslint-disable-next-line prefer-destructuring
      data = parts[1];
      break;
    }
  }

  file.close();

  return data;
}

export default getLastLine;
