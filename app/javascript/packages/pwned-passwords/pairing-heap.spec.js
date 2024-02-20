import PairingHeap from './pairing-heap.js';

describe('PairingHeap', () => {
  const comparator = (a, b) => a - b;

  describe('#pop', () => {
    it('removes and returns the minimum value', () => {
      const heap = new PairingHeap(comparator);

      heap.push(1);
      heap.push(2);
      heap.push(0);
      heap.push(4);
      heap.push(3);

      expect(heap.length).to.equal(5);
      expect(heap.pop()).to.equal(0);
      expect(heap.length).to.equal(4);
      expect(heap.pop()).to.equal(1);
      expect(heap.length).to.equal(3);
      expect(heap.pop()).to.equal(2);
      expect(heap.length).to.equal(2);
      expect(heap.pop()).to.equal(3);
      expect(heap.length).to.equal(1);
      expect(heap.pop()).to.equal(4);
      expect(heap.length).to.equal(0);
    });
  });
});
