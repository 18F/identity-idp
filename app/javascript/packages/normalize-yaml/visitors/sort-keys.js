export default /** @type {import('yaml').visitor} */ ({
  Map(_key, node) {
    node.items.sort(
      /**
       * @param {import('yaml').Pair<any>} a
       * @param {import('yaml').Pair<any>} b
       * @return {number}
       */
      (a, b) => a.key.toString().localeCompare(b.key.toString()),
    );
  },
});
