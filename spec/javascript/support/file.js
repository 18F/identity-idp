import { join, basename, extname } from 'path';
import { promises as fs } from 'fs';

/**
 * Rough approximation of assumed mime type by file extension. This is very incomplete, and assumes
 * files which would be used as fixtures. For a more complete implementation, consider pulling in a
 * package like `mime-types`.
 *
 * @see https://www.npmjs.com/package/mime-types
 *
 * @type {Record<string,string>}
 */
const MIME_TYPES_BY_EXTENSION = {
  '.jpg': 'image/jpeg',
};

/**
 * @typedef {File & {rawBuffer: Buffer}} LoginGovTestFile
 */

/**
 * @param {string} fixturePath
 * @param {BufferEncoding=} encoding
 *
 * @return {Promise<Buffer|string>}
 */
export function getFixture(fixturePath, encoding) {
  const path = join(__dirname, '../../fixtures', fixturePath);
  return fs.readFile(path, encoding);
}

/**
 * @param {string} fixturePath Path relative fixtures directory.
 *
 * @return {Promise<LoginGovTestFile>}
 */
export async function getFixtureFile(fixturePath) {
  const rawBuffer = /** @type {Buffer} */ (await getFixture(fixturePath));
  const type = MIME_TYPES_BY_EXTENSION[extname(fixturePath)];
  const file = new window.File([rawBuffer], basename(fixturePath), { type });
  return Object.assign(file, { rawBuffer });
}

/**
 * @param {LoginGovTestFile} file
 *
 * @return {string} Data URL
 */
export function createObjectURLAsDataURL(file) {
  return `data:${file.type};base64,${file.rawBuffer.toString('base64')}`;
}
