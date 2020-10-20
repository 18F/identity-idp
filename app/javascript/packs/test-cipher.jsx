// @ts-check

import React from 'react';
import { render } from 'react-dom';
import { loadPolyfills } from '@18f/identity-polyfill';
import AesCipher from '../app/utils/aes-cipher';

const appRoot = document.getElementById('cipher-root');

export function toFormData(object) {
  return Object.keys(object).reduce((form, key) => {
    form.append(key, object[key]);
    return form;
  }, new window.FormData());
}

async function doEncryption(event) {
  event.preventDefault();
  // const form = event.currentTarget.closest('[action]');
  const messageBox = document.querySelector('#original-text');
  const message = messageBox.value;
  console.log(`We want to encrypt ${message}`);
  const payload = await AesCipher.encrypt(message);
  const response = await window.fetch(location.href, {
    method: 'POST',
    body: toFormData(payload),
  });
  const json = await response.json();
  document.getElementById('deciphered').innerHTML = json.deciphered;
}

loadPolyfills(['fetch']).then(() => {
  render(
    <div id="react-wrapper">
      <form id="cipher-form" method='post' onSubmit={doEncryption}>
        <label class='usa-label' htmlFor="origtext">Enter some text to encipher:</label>
        <textarea class='usa-textarea margin-bottom-3' type="text" name="origtext" id="original-text" />
        <button type="submit" formMethod="post" class='usa-button'>
          Send to server for decryption
        </button>
      </form>
    </div>,
    appRoot,
  );
});
