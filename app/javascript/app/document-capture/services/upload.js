function upload(payload) {
  return new Promise((resolve, reject) => {
    const isFailure = window.location.search === '?fail';
    setTimeout(isFailure ? reject : () => resolve({ ...payload, saved: true }), 2000);
  });
}

export default upload;
