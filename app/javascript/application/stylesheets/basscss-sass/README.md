# basscss-sass

Transpiled Basscss Sass partials

http://basscss.com

This repository is provided as a convenience for users working within a Sass build process.
Basscss is written in spec-compliant CSS, including some new features like [custom media queries](http://dev.w3.org/csswg/mediaqueries/#custom-mq) and [custom properties](http://www.w3.org/TR/css-variables/), and is distributed across multiple modules.

If you have any choice in the matter, I recommend using a CSS postprocessor like
[cssnext](http://cssnext.github.io/) instead of Sass.


## Getting Started

```bash
npm install basscss-sass
```

```bash
bower install basscss-sass
```

## Sass Tips

- **Never use @extend.** `@extend` is an anti-pattern, and Basscss is not intended to work with this functionality in Sass.
- **Avoid Mixins** Mixins lead to unnecessary complexity, are generally poorly understood, often lead to code bloat, and do not align with Basscss's design principles.
- **Avoid Nesting Selectors** To maintain the composability of Basscss, avoid nesting selectors as much as possible.


## Contributing

**The scss files in this repository are not source files.**
They are transpiled from their respective CSS modules using the 
[css-scss](https://github.com/jxnblk/css-scss) module.

Do **not** edit the scss files in this repository.

If you've found an issue with the transpiler, file an issue on
[css-scss](https://github.com/jxnblk/css-scss/issues).

If you'd like to make modifications to a Basscss module, first,
open an issue in the module's repository.
Read the [design principles](http://www.basscss.com/docs/reference/principles)
and consider the implications of the change in the larger Basscss ecosystem.
If a change does not follow the design principles, it will not be considered.

Feel free to fix typos and make copy suggestions for the readme, or to
suggest fixes for the build process or tests in this repository.

---

MIT License

