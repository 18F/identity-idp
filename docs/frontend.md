# Front-end architecture

## CSS + HTML

- utilizes single-purposed, reusable utility classes (via `Basscss`) to
  build UI components
  - utility classes should do one thing and do it well, should be simple
    and obvious to use, and should operate independently
  - if the markup for something is defined multiple times across templates,
    it should be consolidated to a single place
- leverages elements from the U.S. Web Design Standards (i.e., fonts, colors)
- uses Sass as the CSS preprocessor and `scss-lint` to keep files tidy
- uses well structured, accessible, semantic HTML

## JavaScript

### At a Glance

- site should work if JS is off (and have enhanced features if JS is on)
- uses AirBnB's ESLint config, alongside [Prettier](https://prettier.io/)
- JS modules are installed & managed via `yarn` (see `package.json`)
- JS is transpiled, bundled, and minified via `webpacker` (using
  `rails-webpacker` gem to utilize Rails asset pipeline)

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

Prettier is integrated with [the project's linting setup](#linting). Most issues
can be resolved automatically by running `yarn run lint --fix`. You may also
consider one of the [avaialable editor integrations](https://prettier.io/docs/en/editors.html),
which can simplify your workflow to apply formatting automatically on save.

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
