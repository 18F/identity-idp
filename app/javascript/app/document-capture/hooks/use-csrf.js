function useCSRF() {
  const csrfParam = document.getElementsByName('csrf-param')[0].content;
  const csrfToken = document.getElementsByName('csrf-token')[0].content;
  return [csrfParam, csrfToken];
}

export default useCSRF;
