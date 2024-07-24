export default /** @type {import('./').Visitor} */ (options) => ({
  Map(_key, node) {
    node.items.sort(
      /**
       * @param {import('yaml').Pair<any>} a
       * @param {import('yaml').Pair<any>} b
       * @return {number}
       */
      (a, b) => {
        if (options.ignoreKeySort && options.ignoreKeySort.includes(a.key.toString())) {
          return 0;
        }

        return a.key.toString().localeCompare(b.key.toString());
      },
    );
  },
});
