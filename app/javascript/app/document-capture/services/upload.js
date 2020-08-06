const ENDPOINT = '/api/verify/upload';

function upload(payload, csrf) {
  return fetch(ENDPOINT, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-CSRF-Token': csrf,
    },
    body: JSON.stringify(payload),
  })
    .then((response) => response.json())
    .then((result) => {
      if (!['success', 'error'].includes(result.status)) {
        throw Error('Malformed response');
      }

      return result;
    });
}

export default upload;
