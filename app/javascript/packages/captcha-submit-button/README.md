# `@18f/identity-captcha-submit-button`

Custom element for a form submit button component which invokes a reCAPTCHA challenge before submitting the form.

## Usage

Importing the element will register the `<lg-captcha-submit-button>` custom element:

```ts
import '@18f/identity-captcha-submit-button/captcha-submit-button-element';
```

The custom element will implement behaviors for invoking the challenge upon submission, but all markup must already exist.

```html
<lg-captcha-submit-button recaptcha-site-key="site_key" recaptcha-action="action_name">
  <input type="hidden" name="recaptcha_token">
  <button>Submit</button>
  <script src="https://www.google.com/recaptcha/api.js?render=site_key" async="async"></script>
</lg-captcha-submit-button>
```
