# `@18f/identity-build-sass`

Stylesheet compilation utility with reasonable defaults and fast performance.

Why use it?

- ⚡️ **It's fast**, since it uses native Dart Sass binary through [`sass-embedded`](http://npmjs.com/package/sass-embedded), and the Rust-based [Lightning CSS](https://www.npmjs.com/package/lightningcss) for autoprefixing and minification.
- 💻 **It includes a CLI**, so it's easy to integrate with command-based build pipelines like NPM scripts or Makefile.
- 🚀 **It has relevant defaults**, to work out of the box with minimal or no additional configuration.

Default behavior includes:

- Optimizations enabled based on the `NODE_ENV` environment variable.
- Autoprefixer configuration based on the current project's [Browserslist](https://browsersl.ist/) configuration.
- Automatically adds `node_modules` as a loaded path for Sass compilation.
- Output filenames derived from the input filenames (`main.css.scss` becomes `main.css`).
- Automatically adds required load paths for `@18f/identity-design-system` and `@uswds/uswds`.

## Usage

### CLI

Invoke the included `build-sass` executable with the source files and any relevant command flags.

```
npx build-sass path/to/sass/*.scss
```

Flags:

- `--out-dir`: The output directory
- `--watch`: Run in watch mode, recompiling files on change
- `--load-path`: Include additional path in Sass path resolution
- `--verbose` (`-v`): Output verbose debugging details

### API

#### `buildFile`

Compiles a given Sass file.

```ts
function buildFile(
  file: string,
  options: {
    outDir: string,
    optimize: boolean,
    sassCompiler: SassAsyncCompiler,
    ...sassOptions: SassOptions<'sync'>,
  },
): Promise<SassCompileResult>;
```

## License

This project is in the public domain within the United States, and copyright and related rights in the work worldwide are waived through the [CC0 1.0 Universal public domain dedication](https://creativecommons.org/publicdomain/zero/1.0/).

All contributions to this project will be released under the CC0 dedication. By submitting a pull request or issue, you are agreeing to comply with this waiver of copyright interest.
