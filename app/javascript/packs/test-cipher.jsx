import React from 'react';
import { render } from 'react-dom';
import { loadPolyfills } from '@18f/identity-polyfill';
import AesCipher from '../app/utils/aes-cipher';

const appRoot = document.getElementById('cipher-root');

function doEncryption(event) {
  event.preventDefault();
  const cipher = new AesCipher();
  const messageBox = document.querySelector('#original-text');
  const message = messageBox.value;
  const payload = cipher.encrypt(message);
  console.log('~~~~~~ doEncryption!! ~~~~~~~~~~');
  console.log('message: ', message);
  console.log(cipher);
  console.log("key: ", cipher.key);
  console.log("payload: ", payload);
  document.querySelector('#key').value = cipher.key;
  document.querySelector('#tag').value = payload.tag;
  document.querySelector('#iv').value = payload.iv;
  document.querySelector('#ciphertext').value = payload.ciphertext;
  document.getElementById('#cipher-form').submit();
}

loadPolyfills(['fetch']).then(() => {
  render(
    <div id="react-wrapper">
      <form id="cipher-form">
        <label htmlFor="origtext">Enter some text to encipher:</label>
        <input type="text" name="origtext" id="original-text" />
        <input type="hidden" name="key" id="key" />
        <input type="hidden" name="iv" id="iv" />
        <input type="hidden" name="tag" id="tag" />
        <input type="hidden" name="ciphertext" id="ciphertext"/>
        <button onClick={doEncryption} type="submit" formMethod="post">
          Encipher!
        </button>
      </form>
    </div>,
    appRoot,
  );
});
