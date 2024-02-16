import LinkedList from './linked-list.js';

describe('LinkedList', () => {
  describe('[Symbol.iterator]', () => {
    it('iterates the list', () => {
      const list = new LinkedList();
      list.push(1);
      list.push(2);
      list.push(3);

      expect(Array.from(list)).to.deep.equal([1, 2, 3]);
    });
  });
});
