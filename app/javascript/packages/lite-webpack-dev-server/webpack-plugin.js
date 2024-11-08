const http = require('node:http');
const { join } = require('node:path');
const { createReadStream } = require('node:fs');

/**
 * @typedef PluginOptions
 * @prop {string} [publicPath]
 * @prop {number} [port]
 * @prop {Record<string, string>} [headers]
 */

/**
 * Webpack plugin name.
 *
 * @type {string}
 */
const PLUGIN = 'LiteWebpackDevServerPlugin';

class LiteWebpackDevServerPlugin {
  /**
   * @type {string}
   */
  publicPath;

  /**
   * @type {number}
   */
  port;

  /**
   * @type {Record<string, string>}
   */
  headers;

  /**
   * @param {PluginOptions} options
   */
  constructor(options) {
    Object.assign(this, {
      publicPath: '.',
      port: 3035,
      headers: {
        'content-type': 'text/javascript',
        ...options.headers,
      },
      ...options,
    });
  }

  /**
   * @param {import('webpack').Compiler} compiler
   */
  apply(compiler) {
    /** @type {Promise<void>} */
    let build = Promise.resolve();

    /** @type {() => void} */
    let onCompileFinished;

    const server = http.createServer(async (request, response) => {
      for (const [key, value] of Object.entries(this.headers)) {
        response.setHeader(key, value);
      }

      await build;
      const url = new URL(request.url ?? '', 'file:///');
      const filePath = join(process.cwd(), this.publicPath, url.pathname);
      createReadStream(filePath, 'utf-8').pipe(response);
    });

    server.listen(this.port);

    compiler.hooks.beforeCompile.tap(PLUGIN, () => {
      build = new Promise((resolve) => {
        onCompileFinished = resolve;
      });
    });

    compiler.hooks.afterCompile.tap(PLUGIN, () => onCompileFinished());
  }
}

module.exports = LiteWebpackDevServerPlugin;
