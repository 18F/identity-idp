import { dirname, relative, resolve } from 'path';

/**
 * Returns all file paths contained in the given Sass stack trace.
 *
 * @example
 * ```
 * getErrorSassStackPaths(
 *   '../../../../app/assets/stylesheets/design-system-waiting-room.scss 31:2  @forward\n' +
 *     '../../../../app/assets/stylesheets/application.css.scss 4:1              root stylesheet\n',
 *   'node_modules/sass-embedded-darwin-arm64/dart-sass/src/dart',
 * );
 * // [
 * //   'app/assets/stylesheets/design-system-waiting-room.scss',
 * //   'app/assets/stylesheets/application.css.scss',
 * // ]
 * ```
 *
 * @param {string} sassStack Sass stack trace (see example).
 * @param {string} relativeFrom File from which to resolve relative paths from Sass stack trace.
 *
 * @return {string[]} Array of file paths.
 */
const getErrorSassStackPaths = (sassStack, relativeFrom) =>
  sassStack
    .split(/\.scss \d+:\d+\s+.+?\n/)
    .filter(Boolean)
    .map((basename) => relative('.', resolve(dirname(relativeFrom), `${basename}.scss`)));

export default getErrorSassStackPaths;
