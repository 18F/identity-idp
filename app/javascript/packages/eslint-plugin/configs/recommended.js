const isInstalled = require('../lib/is-installed');

const config = {
  extends: /** @type {string[]} */ ([]),
  plugins: /** @type {string[]} */ ([]),
  env: {
    es6: true,
  },
  rules: {
    'class-methods-use-this': 'off',
    'comma-dangle': 'off',
    'consistent-return': 'off',
    curly: ['error', 'all'],
    'func-names': 'off',
    'function-paren-newline': 'off',
    'prefer-arrow-callback': 'off',
    'import/prefer-default-export': 'off',
    'import/extensions': ['off', 'never'],
    'import/no-extraneous-dependencies': 'error',
    indent: 'off',
    'max-len': 'off',
    'max-classes-per-file': 'off',
    'newline-per-chained-call': 'off',
    'no-cond-assign': ['error', 'except-parens'],
    'no-console': 'error',
    'no-empty': ['error', { allowEmptyCatch: true }],
    'no-param-reassign': ['off', 'never'],
    'no-promise-executor-return': 'off',
    'no-confusing-arrow': 'off',
    'no-plusplus': 'off',
    'no-restricted-syntax': 'off',
    'no-unused-expressions': 'off',
    'no-unused-vars': ['error', { argsIgnorePattern: '^_' }],
    quotes: 'off',
    'implicit-arrow-linebreak': 'off',
    'object-curly-newline': 'off',
    'operator-linebreak': 'off',
    'require-await': 'error',
  },
};

if (isInstalled('@babel/core')) {
  config.parser = '@babel/eslint-parser';
  config.plugins.push('@babel');
  config.rules['@babel/no-unused-expressions'] = 'error';
}

if (isInstalled('prettier')) {
  config.plugins.push('prettier');
  config.rules['prettier/prettier'] = 'error';
}

if (isInstalled('react') || isInstalled('preact')) {
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
    'react/jsx-no-bind': 'off',
    'react/jsx-no-constructed-context-values': 'off',
    'react/jsx-no-useless-fragment': ['error', { allowExpressions: true }],
    'react/jsx-props-no-spreading': 'off',
    'react/jsx-one-expression-per-line': 'off',
    'react/jsx-wrap-multilines': 'off',
    'react/jsx-uses-react': 'off',
    'react/no-unstable-nested-components': 'off',
    'react/react-in-jsx-scope': 'off',
    'react/require-default-props': 'off',
    'react/prop-types': 'off',
  });
} else {
  config.extends.push('airbnb-base');
}

if (isInstalled('mocha')) {
  config.plugins.push('mocha');
  config.env.mocha = true;
  config.rules['mocha/no-skipped-tests'] = 'error';
  config.rules['mocha/no-exclusive-tests'] = 'error';
}

module.exports = config;
