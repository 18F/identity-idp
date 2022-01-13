const babelRegister = require('@babel/register');

babelRegister({ ignore: [/node_modules\/(?!@18f\/identity-)/] });
