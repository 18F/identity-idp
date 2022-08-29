const isInstalled = require('../lib/is-installed');

const config = {
  extends: /** @type {string[]} */ ([]),
  plugins: /** @type {string[]} */ ([]),
  env: {
    es6: true,
  },
  rules: {
    'array-bracket-spacing': 'off',
    'arrow-parens': 'off',
    'arrow-spacing': 'off',
    'block-spacing': 'off',
    'brace-style': 'off',
    'class-methods-use-this': 'off',
    'comma-dangle': 'off',
    'comma-spacing': 'off',
    'comma-style': 'off',
    'computed-property-spacing': 'off',
    'consistent-return': 'off',
    curly: ['error', 'all'],
    'dot-location': 'off',
    'func-call-spacing': 'off',
    'func-names': 'off',
    'function-call-argument-newline': 'off',
    'function-paren-newline': 'off',
    'generator-star-spacing': 'off',
    'prefer-arrow-callback': 'off',
    'import/prefer-default-export': 'off',
    'import/extensions': ['off', 'never'],
    'import/no-extraneous-dependencies': 'error',
    indent: 'off',
    'jsx-quotes': 'off',
    'key-spacing': 'off',
    'keyword-spacing': 'off',
    'max-len': 'off',
    'max-classes-per-file': 'off',
    'newline-per-chained-call': 'off',
    'no-cond-assign': ['error', 'except-parens'],
    'no-console': 'error',
    'no-empty': ['error', { allowEmptyCatch: true }],
    'no-param-reassign': ['off', 'never'],
    'no-promise-executor-return': 'off',
    'no-confusing-arrow': 'off',
    'no-extra-semi': 'off',
    'no-plusplus': 'off',
    'no-restricted-syntax': 'off',
    'no-tabs': 'off',
    'no-trailing-spaces': 'off',
    'no-unused-expressions': 'off',
    'no-unused-vars': ['error', { argsIgnorePattern: '^_' }],
    quotes: 'off',
    'implicit-arrow-linebreak': 'off',
    'object-curly-newline': 'off',
    'object-curly-spacing': 'off',
    'operator-linebreak': 'off',
    'padded-blocks': 'off',
    'prefer-const': ['error', { destructuring: 'all' }],
    'quote-props': 'off',
    'require-await': 'error',
    'rest-spread-spacing': 'off',
    semi: 'off',
    'semi-spacing': 'off',
    'semi-style': 'off',
    'space-before-function-paren': 'off',
    'space-in-parens': 'off',
    'switch-colon-spacing': 'off',
    'template-curly-spacing': 'off',
    'template-tag-spacing': 'off',
    'yield-star-spacing': 'off',
  },
  overrides: /** @type {Array<import('eslint').Linter.ConfigOverride>} */ ([]),
};

if (isInstalled('eslint-plugin-prettier')) {
  config.plugins.push('prettier');
  config.rules['prettier/prettier'] = 'error';
}

if (
  isInstalled('eslint-plugin-react') &&
  isInstalled('eslint-plugin-jsx-a11y') &&
  isInstalled('eslint-plugin-react-hooks')
) {
  config.extends.push('airbnb');
  Object.assign(config.rules, {
    'react/function-component-definition': [
      'error',
      {
        namedComponents: 'function-declaration',
        unnamedComponents: 'arrow-function',
      },
    ],
    'react/jsx-curly-newline': 'off',
    'react/jsx-indent': 'off',
    'react/jsx-filename-extension': ['error', { extensions: ['.jsx', '.tsx'] }],
    'react/jsx-no-bind': 'off',
    'react/jsx-no-constructed-context-values': 'off',
    'react/jsx-no-useless-fragment': ['error', { allowExpressions: true }],
    'react/jsx-props-no-spreading': 'off',
    'react/jsx-one-expression-per-line': 'off',
    'react/jsx-wrap-multilines': 'off',
    'react/jsx-uses-react': 'off',
    'react/no-array-index-key': 'off',
    'react/no-unstable-nested-components': 'off',
    'react/react-in-jsx-scope': 'off',
    'react/require-default-props': 'off',
    'react/prop-types': 'off',
  });
} else {
  config.extends.push('airbnb-base');
}

if (isInstalled('@typescript-eslint/parser') && isInstalled('@typescript-eslint/eslint-plugin')) {
  config.parser = '@typescript-eslint/parser';
  config.plugins.push('@typescript-eslint');
  config.extends.push('plugin:import/typescript');
  Object.assign(config.rules, {
    '@typescript-eslint/default-param-last': ['error'],
    '@typescript-eslint/lines-between-class-members': [
      'error',
      'always',
      {
        exceptAfterSingleLine: false,
      },
    ],
    '@typescript-eslint/no-array-constructor': ['error'],
    '@typescript-eslint/no-dupe-class-members': ['error'],
    '@typescript-eslint/no-empty-function': [
      'error',
      {
        allow: ['arrowFunctions', 'functions', 'methods'],
      },
    ],
    '@typescript-eslint/no-loop-func': ['error'],
    '@typescript-eslint/no-loss-of-precision': ['error'],
    '@typescript-eslint/no-redeclare': 'error',
    '@typescript-eslint/no-shadow': 'error',
    '@typescript-eslint/no-unused-vars': ['error', { argsIgnorePattern: '^_' }],
    '@typescript-eslint/no-use-before-define': 'error',
    '@typescript-eslint/no-useless-constructor': ['error'],
    'default-param-last': 'off',
    'lines-between-class-members': 'off',
    'no-array-constructor': 'off',
    'no-dupe-class-members': 'off',
    'no-empty-function': 'off',
    'no-loop-func': 'off',
    'no-loss-of-precision': 'off',
    'no-redeclare': 'off',
    'no-shadow': 'off',
    'no-unused-vars': 'off',
    'no-use-before-define': 'off',
    'no-useless-constructor': 'off',
  });
  config.overrides.push({
    files: '*.{ts,tsx}',
    rules: {
      'no-undef': 'off',
    },
  });
}

if (isInstalled('eslint-plugin-mocha')) {
  config.plugins.push('mocha');
  config.env.mocha = true;
  config.rules['mocha/no-skipped-tests'] = 'error';
  config.rules['mocha/no-exclusive-tests'] = 'error';
}

module.exports = config;
