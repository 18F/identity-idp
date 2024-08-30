module.exports = {
  extends: ['stylelint-config-standard-scss', 'stylelint-prettier/recommended'],
  rules: {
    'at-rule-empty-line-before': null,
    'color-function-notation': null,
    'declaration-empty-line-before': null,
    'declaration-no-important': true,
    'no-descending-specificity': null,
    'rule-empty-line-before': null,
    'scss/comment-no-empty': null,
    'scss/dollar-variable-empty-line-before': null,
    'scss/double-slash-comment-empty-line-before': null,
    'scss/no-global-function-names': null,
    'scss/operator-no-newline-after': null,
    'scss/operator-no-newline-before': null,
    'scss/operator-no-unspaced': null,
    'selector-class-pattern': [
      '^[a-z]([a-z0-9-]+)?(__([a-z0-9]+-?)+)?(--([a-z0-9]+-?)+){0,2}$',
      {
        message:
          'Class selectors should be named using "Two Dashes Style" BEM format. See: https://en.bem.info/methodology/naming-convention/#two-dashes-style',
        resolveNestedSelectors: true,
      },
    ],
  },
};
