# Front-end architecture

## CSS + HTML

- utilizes single-purposed, reusable utility classes (via `Basscss`) to
  build UI components
  - utility classes should do one thing and do it well, should be simple
    and obvious to use, and should operate independently
  - if the markup for something is defined multiple times across templates,
    it should be consolidated to a single place
- leverages elements from the U.S. Web Design Standards (i.e., fonts, colors)
- uses Sass as the CSS preprocessor and `stylelint` to keep files tidy
- uses well structured, accessible, semantic HTML

## JavaScript

### At a Glance

- Site should work if JS is off (and have enhanced features if JS is on).
- Uses AirBnB's ESLint config, alongside [Prettier](https://prettier.io/).
- JS modules are installed & managed via `yarn` (see `package.json`).
- JS is transpiled, bundled, and minified via `webpacker` (using
  `rails-webpacker` gem to utilize Rails asset pipeline).
- Reusable code is organized using [Yarn workspaces](https://classic.yarnpkg.com/en/docs/workspaces/).

### Prettier

[Prettier](https://prettier.io/) is an opinionated code formatter which
simplifies adherence to JavaScript style standards, both for the developer and
for the reviewer. As a developer, it can eliminate the effort involved with
applying correct formatting. As a reviewer, it avoids most debates over code
style, since there is a consistent style being enforced through the adopted
tooling.

Prettier works reasonably well in combination with Airbnb's JavaScript
standards. In the few cases where conflicts occur, formatting rules may be
disabled to err toward Prettier conventions when an option is not configurable.

Prettier is integrated with [the project's linting setup](#eslint). Most issues
can be resolved automatically by running `yarn run lint --fix`. You may also
consider one of the [available editor integrations](https://prettier.io/docs/en/editors.html),
which can simplify your workflow to apply formatting automatically on save.

### Dependencies

Since the IDP is not a Node.js application or library, the distinction between `dependencies` and `devDependencies` is largely one of communicating intent to other developers on the team based on whether they are brought in to benefit the user or the developer. It does not have a meaningful difference on how those dependencies are used by the application.

In most situations, the following advice should apply:

- `dependencies` include modules which are relevant for runtime (user-facing) features.
  - Examples: Component libraries, input validation libraries
- `devDependencies` include modules which largely support the developer.
  - Examples: Build tools, testing libraries

When installing a dependency, you can make this distinction by including or omitting the `--dev` (`-D`) flag when using `yarn add` or `yarn remove`. Refer to the [Yarn CLI documentation](https://classic.yarnpkg.com/en/docs/cli/) for more information about installing, removing, and upgrading packages.

### Yarn Workspaces

[Workspaces](https://classic.yarnpkg.com/en/docs/workspaces/) allow a developer to create and organize code which is used just like any other NPM package, but which doesn't require the overhead involved in publishing those modules and keeping versions in sync across multiple repositories. The IDP uses Yarn workspaces to keep JavaScript code organized, reusable, and to encourage good coding practices in abstractions.

In practice:

- All folders within `app/javascript/packages` are treated as workspace packages.
- Each package should have its own `package.json` that includes...
  - ...a `name` starting with `@18f/identity-` and ending with the name of the package folder.
  - ...a listing of its own dependencies, including to other workspace packages using [`file:` prefix](https://classic.yarnpkg.com/en/docs/cli/add/).
  - ...[`"private": true`](https://docs.npmjs.com/files/package.json#private), since workspaces packages are currently not published to NPM.
  - ...a value for the `version` field, since it is required. The value value can be anything, and `"1.0.0"` is a good default.
- Each package should include an `index.js` which serves as the entry-point and public API for the package.

A package might have a corresponding file by the same package name contained within `app/javascript/packs` that serves as the integration point between packages and the Rails application. This is to encourage packages to be reusable, where the file in `packs` contains any logic required to wire the package to the running Rails application. Because Yarn will alias workspace packages using symlinks, you can reference a package using the name you assigned using the guidelines above for `package.json` `name` field (for example, `import { Button } from '@18f/identity-components';`).

## Testing

### At a Glance

- integration tests and unit tests should always be running and passing
- tests should be added/updated with new functionality and when features
  are changed
- attempt to unit test data-related JS; functional/integration tests are
  fine for DOM-related code

### Running Tests

#### Mocha

[Mocha](https://mochajs.org/) is used as a test runner for JavaScript code.

To run all test specs:

```
yarn test
```

To run a single test file:

```
npx mocha spec/javascripts/app/utils/ms-formatter_spec.js
```

Using `npx`, you can also pass any [Mocha command-line arguments](https://mochajs.org/#command-line-usage).

For example, to watch a file and rerun tests after any change:

```
npx mocha spec/javascripts/app/utils/ms-formatter_spec.js --watch
```

#### ESLint

[ESLint](https://eslint.org/) is used to ensure code quality and enforce styling conventions.

To analyze all JavaScript files:

```
yarn run lint
```

Many issues can be fixed automatically by appending a `--fix` flag to the command:

```
yarn run lint --fix
```

## Devices

- strive to support all browsers with > 1% usage
- site should look good and work well across all device sizes
