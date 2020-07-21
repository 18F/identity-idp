import { JSDOM } from 'jsdom';

/*
  This is the intial HTML for document capture pulled from rendering a view with
   the partial at app/views/idv/_acuant_sdk_document_capture_form.html.erb
*/
const INITIAL_HTML = `
<input type='hidden' id='doc_auth_image_data_url'>

<div id='acuant-fallback-image-form'>
  <input type='file' id='doc_auth_image' required>
  <input type='submit' value='continue' class='btn btn-primary'>
</div>

<div id='acuant-sdk-upload-form' class='hidden'>
  <button id='acuant-sdk-capture' class='btn btn-primary'>Choose image</button>
</div>

<div id='acuant-sdk-spinner' class='hidden'>
  <img src='wait.gif' width=50 height=50>
</div>

<video id="acuant-player" controls autoPlay playsInline class='hidden'></video>
<div id='acuant-sdk-capture-view' class='hidden'>
    <div id='acuant-sdk-capture-view-close'></div>
  <canvas id="acuant-video-canvas" style='width: 100%;'></canvas>
</div>

<div id='acuant-sdk-continue-form' class='hidden'>
  <img id='acuant-sdk-preview'>
  <input type='submit' value='Continue' class='btn btn-primary btn-wide mt2'>
</div>

<p id='acuant-fallback-text' class='my3 hidden'>
  Having trouble?
  <a href='/' id='acuant-fallback-link'>
    Click here to upload an image.
  </a>
</p>
`;

let originalWindow;
let originalDocument;

export const setupDocumentCaptureTestDOM = () => {
  originalWindow = global.window;
  originalDocument = global.document;

  // While there's already DOM globals, the current implementation assumes a
  // cleanly initialized DOM in every test case. Ideally all event handlers
  // attached to the DOM in the course of a test case would be cleaned up, and
  // the same DOM could be reused for every test.
  const dom = new JSDOM(INITIAL_HTML);
  global.window = dom.window;
  global.document = global.window.document;
};

export const teardownDocumentCaptureTestDOM = () => {
  global.window = originalWindow;
  global.document = originalDocument;
};
