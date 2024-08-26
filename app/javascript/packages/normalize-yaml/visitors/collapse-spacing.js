export default /** @type {import('./').Visitor} */ (_options) => ({
  Scalar(_key, node) {
    if (typeof node.value === 'string') {
      node.value = node.value.replace(/ {2,}/g, ' ');
    }
  },
});
