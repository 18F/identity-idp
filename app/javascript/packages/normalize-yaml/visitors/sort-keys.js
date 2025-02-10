export default /** @type {import('./').Visitor} */ ({ ignoreKeySort }) => ({
  Map(_key, node) {
    node.items.sort(
      /**
       * @param {import('yaml').Pair<any>} a
       * @param {import('yaml').Pair<any>} b
       * @return {number}
       */
      (a, b) => {
        const aKey = a.key.toString();
        const bKey = b.key.toString();

        if (ignoreKeySort && (ignoreKeySort.includes(aKey) || ignoreKeySort.includes(bKey))) {
          return 0;
        }

        return aKey.localeCompare(bKey);
      },
    );
  },
});
