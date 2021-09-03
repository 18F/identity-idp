module.exports = {
  extends: ['airbnb'],
  parser: '@babel/eslint-parser',
  plugins: ['prettier', '@babel', 'mocha'],
  env: {
    es6: true,
    mocha: true,
  },
  rules: {
    '@babel/no-unused-expressions': 'error',
    'class-methods-use-this': 'off',
    'consistent-return': 'off',
    curly: ['error', 'all'],
    'prettier/prettier': 'error',
    'func-names': 'off',
    'function-paren-newline': 'off',
    'prefer-arrow-callback': 'off',
    'import/prefer-default-export': 'off',
    'import/extensions': ['off', 'never'],
    'import/no-extraneous-dependencies': 'error',
    indent: 'off',
    'max-len': 'off',
    'max-classes-per-file': 'off',
    'mocha/no-skipped-tests': 'error',
    'mocha/no-exclusive-tests': 'error',
    'newline-per-chained-call': 'off',
    'no-console': 'error',
    'no-empty': ['error', { allowEmptyCatch: true }],
    'no-param-reassign': ['off', 'never'],
    'no-confusing-arrow': 'off',
    'no-plusplus': 'off',
    'no-restricted-syntax': 'off',
    'no-unused-expressions': 'off',
    'no-unused-vars': ['error', { argsIgnorePattern: '^_' }],
    'implicit-arrow-linebreak': 'off',
    'object-curly-newline': 'off',
    'operator-linebreak': 'off',
    'react/jsx-curly-newline': 'off',
    'react/jsx-indent': 'off',
    'react/jsx-no-bind': 'off',
    'react/jsx-props-no-spreading': 'off',
    'react/jsx-one-expression-per-line': 'off',
    'react/jsx-wrap-multilines': 'off',
    'react/jsx-uses-react': 'off',
    'react/react-in-jsx-scope': 'off',
    'react/prop-types': 'off',
    'require-await': 'error',
  },
};
