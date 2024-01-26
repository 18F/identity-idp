export default /** @type {import('yaml').visitor} */ ({
  Scalar(_key, node) {
    if (typeof node.value === 'string') {
      node.value = node.value.replace(/(\w)\. {2,}/g, '$1. ');
    }
  },
});
