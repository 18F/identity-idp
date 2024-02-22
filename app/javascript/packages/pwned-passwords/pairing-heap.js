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
   * Returns the top value of the heap.
   *
   * @return {V}
   */
  peek() {
    return /** @type {Heap<V>} */ (this.heap).value;
  }

  /**
   * Adds a new value to the heap.
   *
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
   * Removes and returns the top value from the heap.
   *
   * @return {V}
   */
  pop() {
    const { value, head } = /** @type {Heap<V>} */ (this.heap);

    this.heap = this.#mergePairs(head);
    this.length--;

    return value;
  }

  /**
   * Melds pairs of heaps to a new heap.
   *
   * @param {Heap<V> | undefined} heap
   * @return {Heap<V> | undefined}
   */
  #mergePairs(heap) {
    // Pass 1: Build pairs left-to-right

    /** @type {Heap<V> | undefined} */
    let current = heap;
    /** @type {Array<[Heap<V>, Heap<V> | undefined]>} */
    const pairs = [];
    while (current) {
      const nextSequence = current.next?.next;
      pairs.push([current, current.next]);
      if (current.next) {
        current.next.next = undefined;
      }
      current.next = undefined;
      current = nextSequence;
    }

    // Pass 2: Merge pairs right-to-left

    /** @type {Heap<V> | undefined} */
    let result;
    while (pairs.length) {
      const pairB = /** @type {[Heap<V>, Heap<V> | undefined]} */ (pairs.pop());
      const pairA = pairs.pop();
      if (pairA) {
        result = this.#merge(result, this.#merge(this.#merge(...pairA), this.#merge(...pairB)));
      } else {
        result = this.#merge(result, this.#merge(...pairB));
      }
    }

    return result;
  }

  /**
   * Merges two heaps.
   *
   * @param {Heap<V> | undefined} a
   * @param {Heap<V> | undefined} b
   * @return {Heap<V> | undefined}
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
