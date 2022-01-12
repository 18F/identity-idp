const swcRegister = require('@swc/register');

swcRegister({ ignore: [/node_modules\/(?!@18f\/identity-)/] });
