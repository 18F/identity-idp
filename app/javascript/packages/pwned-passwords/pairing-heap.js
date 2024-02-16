/**
 * @template V
 * @typedef {(a: V, b: V) => number} Comparator
 */

/**
 * @template V
 * @typedef {{ value: V, head?: Heap<V>, next?: Heap<V> }} Heap
 */

/**
 * @template V
 */
class PairingHeap {
  /** @type {Comparator<V>} */
  comparator;

  /** @type {Heap<V> | undefined} */
  heap;

  /** @type {number} */
  length = 0;

  /**
   * @param {Comparator<V>} comparator
   */
  constructor(comparator) {
    this.comparator = comparator;
  }

  *[Symbol.iterator]() {
    if (!this.heap) {
      return;
    }

    /** @type {Heap<V>[]} */
    const queue = [this.heap];
    for (let i = 0; i < queue.length; i++) {
      const { value, head, next } = queue[i];

      yield value;

      if (next) {
        queue.push(next);
      }

      if (head) {
        queue.push(head);
      }
    }
  }

  /**
   * @return {V}
   */
  peek() {
    return /** @type {Heap<V>} */ (this.heap).value;
  }

  /**
   * @param {V} value
   */
  push(value) {
    if (this.heap) {
      this.heap = this.#merge(this.heap, { value });
    } else {
      this.heap = { value };
    }

    this.length++;
  }

  /**
   * @return {V}
   */
  pop() {
    const { value, head } = /** @type {Heap<V>} */ (this.heap);

    this.heap = this.#mergePairs(head);
    this.length--;

    return value;
  }

  /**
   * @param {Heap<V> | undefined} heap
   * @return {Heap<V>|undefined}
   */
  #mergePairs(heap) {
    if (heap === undefined) {
      return;
    }

    const { next } = heap;
    if (!next) {
      return heap;
    }

    const nextSequence = next.next;
    heap.next = undefined;
    next.next = undefined;

    return this.#merge(this.#merge(heap, next), this.#mergePairs(nextSequence));
  }

  /**
   * @param {Heap<V>|undefined} a
   * @param {Heap<V>|undefined} b
   * @return {Heap<V>|undefined}
   */
  #merge(a, b) {
    if (a === undefined) {
      return b;
    }

    if (b === undefined) {
      return a;
    }

    if (this.comparator(a.value, b.value) < 0) {
      b.next = a.head;
      a.head = b;
      return a;
    }

    a.next = b.head;
    b.head = a;
    return b;
  }
}

export default PairingHeap;
