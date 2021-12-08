module.exports = {
  extends: ['stylelint-config-recommended-scss', 'stylelint-prettier/recommended'],
  rules: {
    'no-descending-specificity': null,
    'scss/comment-no-empty': null,
    'scss/no-global-function-names': null,
    'selector-class-pattern': '^[a-z]([a-z0-9-]+)?(__([a-z0-9]+-?)+)?(--([a-z0-9]+-?)+){0,2}$',
  },
};
