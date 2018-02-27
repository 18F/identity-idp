export default () => {
  window.onbeforeunload = null;
  window.onunload = null;
  window.location.href = '/timeout';
};
