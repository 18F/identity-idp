function useCSRF() {
  return document.getElementsByName('csrf-token')[0].content;
}

export default useCSRF;
