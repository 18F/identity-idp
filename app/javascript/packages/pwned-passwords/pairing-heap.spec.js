import PairingHeap from './pairing-heap.js';

describe('PairingHeap', () => {
  const comparator = (a, b) => a - b;

  it('behaves like a sorted array', () => {
    const array = [...Array(100)].map(() => Math.random());
    const heap = new PairingHeap(comparator);

    array.forEach((value) => heap.push(value));

    expect(Array.from(heap)).to.have.members(array);

    for (const sortedValue of array.sort(comparator)) {
      expect(heap.pop()).to.equal(sortedValue);
    }

    expect(heap.length).to.equal(0);
  });

  describe('#Symbol.iterator', () => {
    it('iterates members of the heap', () => {
      const heap = new PairingHeap(comparator);

      heap.push(1);
      heap.push(2);
      heap.push(0);
      heap.push(4);
      heap.push(3);

      expect(Array.from(heap)).to.have.members([0, 1, 2, 3, 4]);
    });
  });

  describe('#peek', () => {
    it('returns the least value', () => {
      const heap = new PairingHeap(comparator);

      heap.push(1);
      heap.push(2);
      heap.push(0);
      heap.push(4);
      heap.push(3);

      expect(heap.peek()).to.equal(0);
    });
  });

  describe('#push', () => {
    it('merges to the heap', () => {
      const heap = new PairingHeap(comparator);

      heap.push(1);
      heap.push(2);
      heap.push(0);
      heap.push(4);
      heap.push(3);

      expect(Array.from(heap)).to.have.members([0, 1, 2, 3, 4]);
    });

    it('maintains minimum value in merge', () => {
      const heap = new PairingHeap(comparator);

      heap.push(1);
      expect(heap.peek()).to.equal(1);
      heap.push(2);
      expect(heap.peek()).to.equal(1);
      heap.push(0);
      expect(heap.peek()).to.equal(0);
      heap.push(4);
      expect(heap.peek()).to.equal(0);
      heap.push(3);
      expect(heap.peek()).to.equal(0);
    });
  });

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

    it('merges subheaps', () => {
      const heap = new PairingHeap(comparator);

      heap.push(1);
      heap.push(2);
      heap.push(0);
      heap.push(4);
      heap.push(3);

      expect(heap.peek()).to.equal(0);
      expect(heap.pop()).to.equal(0);
      expect(heap.peek()).to.equal(1);
      expect(heap.pop()).to.equal(1);
      expect(heap.peek()).to.equal(2);
      expect(heap.pop()).to.equal(2);
      expect(heap.peek()).to.equal(3);
      expect(heap.pop()).to.equal(3);
      expect(heap.peek()).to.equal(4);
      expect(heap.pop()).to.equal(4);
    });
  });
});
