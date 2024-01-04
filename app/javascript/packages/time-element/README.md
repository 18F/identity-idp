# `@18f/identity-time-element`

Custom element which converts a time string rendered by the server into the user's local time.

## Usage

The package exports a `TimeElement` custom element, which can be registered using the browser's custom element registry:

```ts
import { TimeElement } from '@18f/identity-time-element';

customElements.define('lg-time', TimeElement);
```

The custom element will implement associated behaviors, but all markup must already exist.

```html
<lg-time data-timestamp="2023-09-26T20:20:26Z" data-format="%{month} %{day}, %{year} at %{hour}:%{minute} %{day_period}">
  September 26, 2023 at 4:20 PM
</lg-time>
```
