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

const decode = function (text) {
  const enc = new TextDecoder();
  return enc.decode(text);
};

async function doEncryption(event) {
  event.preventDefault();
  const messageBox = document.querySelector('#original-text');
  const message = messageBox.value;
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
        <label className="usa-label" htmlFor="origtext">
          Enter some text to encipher:
        </label>
        <textarea className="usa-textarea margin-bottom-3" name="origtext" id="original-text" />
        <button className='usa-button' type="submit" formMethod="post">
          Send to server for decryption
        </button>
      </form>
    </div>,
    appRoot,
  );
});
