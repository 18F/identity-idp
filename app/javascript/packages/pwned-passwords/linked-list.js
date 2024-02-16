/**
 * @template V
 * @typedef LinkedListNode
 * @prop {V} value
 * @prop {LinkedListNode<V>=} next
 */

/**
 * @template V
 */
class LinkedList {
  /** @type {LinkedListNode<V> | undefined} */
  head;

  /** @type {LinkedListNode<V> | undefined} */
  tail;

  /**
   * @return {Iterator<V>}
   */
  *[Symbol.iterator]() {
    let next = this.head;
    while (next) {
      yield next.value;
      next = next.next;
    }
  }

  /**
   * @param {V} value
   */
  push(value) {
    /** @type {LinkedListNode<V>} */
    const node = { value };
    if (this.tail) {
      this.tail.next = node;
    }

    this.tail = node;

    if (!this.head) {
      this.head = node;
    }
  }
}

export default LinkedList;
