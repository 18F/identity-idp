export default /** @type {import('yaml').visitor} */ ({
  Scalar(_key, node) {
    if (typeof node.value === 'string') {
      node.value = node.value.replace(/ {2,}/g, ' ');
    }
  },
});
