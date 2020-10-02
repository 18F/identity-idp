const babelRegister = require('@babel/register');

babelRegister({ ignore: [/node_modules\/(?!@18f\/identity-)/] });

// Ignore SCSS imports. These are handled by Webpack in the browser build, but will cause parse
// errors if loaded in Node.
require.extensions['.scss'] = () => {};
