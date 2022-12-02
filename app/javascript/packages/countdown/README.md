# `@18f/identity-countdown`

Custom elements for countdown interface elements.

## Usage

### Countdown

Importing the element will register the `<lg-countdown>` custom element:

```ts
import '@18f/identity-countdown/countdown-element';
```

The custom element will implement the countdown behavior, but all markup must already exist.

```html
<lg-countdown
  data-expiration="2022-12-02T14:50:32Z"
  data-update-interval="1000"
  data-start-immediately="true"
>
  0 seconds
</lg-countdown>
```

### CountdownAlert

Importing the element will register the `<lg-countdown-alert>` custom element:

```ts
import '@18f/identity-countdown/countdown-alert-element';
```

The custom element will implement the countdown alert behavior, but all markup must already exist.

```html
<lg-countdown-alert show-at-remaining-seconds="150">
  <div class="usa-alert usa-alert--info margin-bottom-4 usa-alert--info-time" role="status">
    <div class="usa-alert__body">
      <p class="usa-alert__text">
        <lg-countdown
          data-expiration="2022-12-02T14:50:32Z"
          data-update-interval="1000"
          data-start-immediately="true"
        >
          0 seconds
        </lg-countdown>
      </p>
    </div>
  </div>
</lg-countdown-alert>
```
