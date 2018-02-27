# Front-end architecture

### CSS + HTML

- utilizes single-purposed, reusable utility classes (via `Basscss`) to
  build UI components
  - utility classes should do one thing and do it well, should be simple
    and obvious to use, and should operate independently
  - if the markup for something is defined multiple times across templates,
    it should be consolidated to a single place
- leverages elements from the U.S. Web Design Standards (i.e., fonts, colors)
- uses Sass as the CSS preprocessor and `scss-lint` to keep files tidy
- uses well structured, accessible, semantic HTML

### JavaScript

- site should work if JS is off (and have enhanced features if JS is on)
- uses AirBnB's ESLint config
- JS modules are installed & managed via `yarn` (see `package.json`)
- JS is transpiled, bundled, and minified via `webpacker` (using
  `rails-webpacker` gem to utilize Rails asset pipeline)

### Testing

- integration tests and unit tests should always be running and passing
- tests should be added/updated with new functionality and when features
  are changed
- attempt to unit test data-related JS; functional/integration tests are
  fine for DOM-related code

### Devices

- strive to support all browsers with > 1% usage
- site should look good and work well across all device sizes
