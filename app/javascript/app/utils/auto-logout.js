export default (path) => {
  window.onbeforeunload = null;
  window.onunload = null;
  window.location.href = path;
};
