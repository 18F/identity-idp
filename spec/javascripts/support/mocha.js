const babelRegister = require('@babel/register');

babelRegister({
  ignore: [/node_modules\/(?!@18f\/identity-)/],
  extensions: ['.js', '.jsx', '.ts', '.tsx'],
});

globalThis.IS_REACT_ACT_ENVIRONMENT = true;
