# `@18f/identity-phone-input`

Custom element implementation initializes an interactive phone input, using [`intl-tel-input`](https://github.com/jackocnr/intl-tel-input).

## Usage

Importing the element will register the `<lg-phone-input>` custom element:

```ts
import '@18f/identity-phone-input';
```

The custom element will implement associatd behaviors, but all markup must already exist.

```html
<lg-phone-input data-delivery-methods="[&quot;sms&quot;,&quot;voice&quot;]" data-translated-country-code-names="{&quot;us&quot;:&quot;United States&quot;}" data-captcha-exempt-countries="[&quot;US&quot;]">
  <script type="application/json" class="phone-input__strings">{"country_code_label":"Country code","invalid_phone_us":"Enter a 10 digit phone number.","invalid_phone_international":"Enter a phone number with the correct number of digits.","unsupported_country":"We are unable to verify phone numbers from %{location}"}</script>
  <div class="phone-input__international-code-wrapper">
    <label for="international-code">Country code</label>
    <select
      id="international-code"
      class="phone-input__international-code"
      data-countries="[&quot;US&quot;]"
    >
      <option data-supports-sms="true" data-supports-voice="true" data-country-code="1" data-country-name="United States" value="US">United States +1</option>
    </select>
  </div>
  <label for="phone-number">Phone number</label>
  <input id="phone-number" class="phone-input__number">
</lg-phone-input>
```
