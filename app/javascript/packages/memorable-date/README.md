# `@18f/identity-memorable-date`

Custom element implementing behaviors associated with Login.gov's adaptation of the U.S. Web Design System [Memorable Date component](https://designsystem.digital.gov/components/memorable-date/).

## Usage

Importing the element will register the `<lg-memorable-date>` custom element:

```ts
import '@18f/identity-memorable-date/memorable-date-element';
```

The custom element will implement modal behavior, but all markup must already exist.

```html
<lg-memorable-date>
  <script type="application/json" class="memorable-date__error-strings"></script>
  <input type="text" class="memorable-date__month" />
  <input type="text" class="memorable-date__day" />
  <input type="text" class="memorable-date__year" />
</lg-memorable-date>
```
