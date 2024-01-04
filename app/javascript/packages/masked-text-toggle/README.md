# `@18f/identity-masked-text-toggle`

Package implementing behaviors associated with toggling the visibility of text which is masked by default due to its sensitivity.

For example, a Social Security number may be masked to show only `6**-**-***4` by default, and allow a user to toggle the visibility of the full number if desired.

## Usage

Initialize the package's binding with the polling endpoint and required elements:

```ts
import MaskedTextToggle from '@18f/identity-masked-text-toggle';

const toggle = document.querySelector('.masked-text-toggle');
new MaskedTextToggle(toggle).bind();
```

The given toggle element is expected to be a checkbox, associated with the masked text wrapper by an `aria-controls` attribute.

The masked text wrapper is expected to contain two variations of the text: a masked form (with a `data-masked="true"` attribute) and a revealed form (with a `data-masked="false"` attribute). The package will toggle visibility using the `display-none` utility class from the U.S. Web Design System.

```html
<span id="masked-text">
  <span data-masked="true">
    6**-**-***4
  </span>
  <span class="display-none" data-masked="false">
    666-12-1234
  </span>
</span>
<input type="checkbox" aria-controls="masked-text">
```
