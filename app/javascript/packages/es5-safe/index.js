import { promises as fsPromises } from 'fs';
import { cpus } from 'os';
import pAll from 'p-all';
import glob from 'fast-glob';
import acorn from 'acorn';

const { readFile } = fsPromises;

/**
 * Returns a promise resolving to a boolean representing whether the file contains valid ES5 syntax.
 *
 * @param {string} file File path.
 *
 * @return {Promise<boolean>} Promise resolving to safety of file.
 */
export async function isSafe(file) {
  try {
    const fileText = await readFile(file, 'utf8');
    acorn.parse(fileText, { ecmaVersion: 5 });
    return true;
  } catch (error) {
    console.error(file, error);
    return false;
  }
}

/**
 * Returns a promise resolving to a boolean representing whether the files corresponding to the
 * given glob patterns contain valid ES5 syntax.
 *
 * @param {string[]} patterns Glob patterns.
 *
 * @return {Promise<boolean>} Promise resolving to safety of files corresponding to glob patterns.
 */
export async function isAllSafe(patterns) {
  const files = glob.stream(patterns);

  const queue = [];
  for await (const file of files) {
    queue.push(() => isSafe(file));
  }

  return (await pAll(queue, { concurrency: cpus().length })).every(Boolean);
}
