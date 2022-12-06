import getErrorSassStackPaths from './get-error-sass-stack-paths.js';

describe('getErrorSassStackPaths', () => {
  it('returns an array of paths from a sass stack message', () => {
    const stackPaths = getErrorSassStackPaths(
      'node_modules/identity-style-guide/dist/assets/scss/uswds/core/_functions.scss 35:8     divide()\n' +
        'node_modules/identity-style-guide/dist/assets/scss/uswds/core/mixins/_icon.scss 77:12  add-color-icon()\n' +
        'app/assets/stylesheets/components/_alert.scss 13:5                                     @import\n' +
        'app/assets/stylesheets/components/all.scss 3:9                                         @import\n' +
        'app/assets/stylesheets/application.css.scss 7:9                                        root stylesheet\n',
    );

    expect(stackPaths).to.deep.equal([
      'node_modules/identity-style-guide/dist/assets/scss/uswds/core/_functions.scss',
      'node_modules/identity-style-guide/dist/assets/scss/uswds/core/mixins/_icon.scss',
      'app/assets/stylesheets/components/_alert.scss',
      'app/assets/stylesheets/components/all.scss',
      'app/assets/stylesheets/application.css.scss',
    ]);
  });

  context('with a stack path containing a space', () => {
    it('returns an array of paths from a sass stack message', () => {
      const stackPaths = getErrorSassStackPaths(
        'node_modules/identity-style-guide/dist/assets/scss/uswds/core/_functions.scss 35:8     divide()\n' +
          'node_modules/identity-style-guide/dist/assets/scss/uswds/core/mixins/_icon.scss 77:12  add-color-icon()\n' +
          'app/assets/stylesheets/components/_alert example.scss 13:5                             @import\n' +
          'app/assets/stylesheets/components/all.scss 3:9                                         @import\n' +
          'app/assets/stylesheets/application.css.scss 7:9                                        root stylesheet\n',
      );

      expect(stackPaths).to.deep.equal([
        'node_modules/identity-style-guide/dist/assets/scss/uswds/core/_functions.scss',
        'node_modules/identity-style-guide/dist/assets/scss/uswds/core/mixins/_icon.scss',
        'app/assets/stylesheets/components/_alert example.scss',
        'app/assets/stylesheets/components/all.scss',
        'app/assets/stylesheets/application.css.scss',
      ]);
    });
  });
});
