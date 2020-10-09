import { promises as fsPromises } from 'fs';
import { cpus } from 'os';
import pAll from 'p-all';
import glob from 'fast-glob';
import acorn from 'acorn';

const { readFile } = fsPromises;

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

export async function isAllSafe(patterns) {
  const files = glob.stream(patterns);

  const queue = [];
  for await (const file of files) {
    queue.push(() => isSafe(file));
  }

  return (await pAll(queue, { concurrency: cpus().length })).every(Boolean);
}
