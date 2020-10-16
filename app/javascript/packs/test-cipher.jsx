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

function doEncryption(event) {
  event.preventDefault();
  // const form = event.currentTarget.closest('[action]');
  const messageBox = document.querySelector('#original-text');
  const message = messageBox.value;
  AesCipher.encrypt(message).then((payload) => {
    console.log('~~~~~~ doEncryption!! ~~~~~~~~~~');
    console.log('message: ', message);
    // console.log(cipher);
    // console.log("key: ", cipher.key);
    // console.log("rawkey: ", cipher.rawkey);
    console.log("payload: ", payload);
    window.fetch(location.href, {
      method: 'POST',
      body: toFormData(payload),
    });
  });
  // document.querySelector('#key').value = payload.key;
  // document.querySelector('#tag').value = payload.tag;
  // document.querySelector('#iv').value = payload.iv;
  // document.querySelector('#ciphertext').value = payload.ciphertext;
  // document.getElementById('cipher-form').submit();
}

loadPolyfills(['fetch']).then(() => {
  render(
    <div id="react-wrapper">
      <form id="cipher-form" method='post' onSubmit={doEncryption}>
        <label htmlFor="origtext">Enter some text to encipher:</label>
        <input type="text" name="origtext" id="original-text" />
        <input type="hidden" name="key" id="key" />
        <input type="hidden" name="iv" id="iv" />
        <input type="hidden" name="tag" id="tag" />
        <input type="hidden" name="ciphertext" id="ciphertext"/>
        <button type="submit" formMethod="post">
          Encipher!
        </button>
      </form>
    </div>,
    appRoot,
  );
});
