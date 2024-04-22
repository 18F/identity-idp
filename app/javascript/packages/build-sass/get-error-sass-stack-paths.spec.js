import getErrorSassStackPaths from './get-error-sass-stack-paths.js';

describe('getErrorSassStackPaths', () => {
  it('returns an array of paths from a sass stack message resolved from relative file', () => {
    const stackPaths = getErrorSassStackPaths(
      '../../../../app/assets/stylesheets/design-system-waiting-room.scss 31:2  @forward\n' +
        '../../../../app/assets/stylesheets/application.css.scss 4:1              root stylesheet\n',
      'node_modules/sass-embedded-darwin-arm64/dart-sass/src/dart',
    );

    expect(stackPaths).to.deep.equal([
      'app/assets/stylesheets/design-system-waiting-room.scss',
      'app/assets/stylesheets/application.css.scss',
    ]);
  });

  context('with a stack path containing a space', () => {
    it('returns an array of paths from a sass stack message resolved from relative file', () => {
      const stackPaths = getErrorSassStackPaths(
        '../../../../app/assets/stylesheets/design-system waiting-room.scss 31:2  @forward\n' +
          '../../../../app/assets/stylesheets/application.css.scss 4:1              root stylesheet\n',
        'node_modules/sass-embedded-darwin-arm64/dart-sass/src/dart',
      );

      expect(stackPaths).to.deep.equal([
        'app/assets/stylesheets/design-system waiting-room.scss',
        'app/assets/stylesheets/application.css.scss',
      ]);
    });
  });
});
