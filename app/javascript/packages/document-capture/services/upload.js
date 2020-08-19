/** @typedef {import('../context/upload').UploadSuccessResponse} UploadSuccessResponse */
/** @typedef {import('../context/upload').UploadErrorResponse} UploadErrorResponse */

/**
 * Returns a FormData representation of the given object.
 *
 * @param {Record<string,any>} object Object to serialize.
 *
 * @return {FormData}
 */
export function toFormData(object) {
  return Object.keys(object).reduce((form, key) => {
    form.append(key, object[key]);
    return form;
  }, new window.FormData());
}

/**
 * @type {import('../context/upload').UploadImplementation}
 */
async function upload(payload, { endpoint, csrf, sessionUUID }) {
  const payloadWithSessionUUID = { ...payload, document_capture_session_uuid: sessionUUID };
  const response = await window.fetch(endpoint, {
    method: 'POST',
    headers: {
      'X-CSRF-Token': csrf,
    },
    body: toFormData(payloadWithSessionUUID),
  });

  if (!response.ok && response.status !== 400) {
    // 400 is an expected error state, handled after JSON deserialization. Anything else not OK
    // should be treated as an unhandled error.
    throw new Error(response.statusText);
  }

  const result = /** @type {UploadSuccessResponse|UploadErrorResponse} */ (await response.json());
  if (!result.success) {
    throw Error(/** @type {UploadErrorResponse} */ (result).errors.join(', '));
  }

  return /** @type {UploadSuccessResponse} */ (result);
}

export default upload;
