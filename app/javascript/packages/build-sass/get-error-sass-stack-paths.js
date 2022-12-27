/**
 * Returns all file paths contained in the given Sass stack trace.
 *
 * @example
 * ```
 * getErrorSassStackPaths(
 *   'node_modules/identity-style-guide/dist/assets/scss/uswds/core/_functions.scss 35:8     divide()\n' +
 *   'node_modules/identity-style-guide/dist/assets/scss/uswds/core/mixins/_icon.scss 77:12  add-color-icon()\n' +
 *   'app/assets/stylesheets/components/_alert.scss 13:5                                     @import\n' +
 *   'app/assets/stylesheets/components/all.scss 3:9                                         @import\n' +
 *   'app/assets/stylesheets/application.css.scss 7:9                                        root stylesheet\n',
 * );
 * // [
 * //   'node_modules/identity-style-guide/dist/assets/scss/uswds/core/_functions.scss',
 * //   'node_modules/identity-style-guide/dist/assets/scss/uswds/core/mixins/_icon.scss',
 * //   'app/assets/stylesheets/components/_alert.scss',
 * //   'app/assets/stylesheets/components/all.scss',
 * //   'app/assets/stylesheets/application.css.scss',
 * // ]
 * ```
 *
 * @param {string} sassStack Sass stack trace (see example).
 *
 * @return {string[]} Array of file paths.
 */
const getErrorSassStackPaths = (sassStack) =>
  sassStack
    .split(/\.scss \d+:\d+\s+.+?\n/)
    .filter(Boolean)
    .map((basename) => `${basename}.scss`);

export default getErrorSassStackPaths;
