const noOp = function() {};

class Events {
  constructor() {
    this.handlers = {};
  }

  on(eventName, handler = noOp, context = null) {
    if (!eventName) return;

    const handlersForEvent = this.handlers[eventName] || [];

    if (!handlersForEvent.filter(obj => obj.handler === handler).length) {
      handlersForEvent.push({ handler, context });
    }

    this.handlers[eventName] = handlersForEvent;
  }

  off(eventName, handler) {
    if (!eventName) {
      Object.keys(this.handlers).forEach((name) => {
        this.handlers[name].length = 0;
      });
    } else if (!handler || typeof handler !== 'function') {
      this.handlers[eventName].length = 0;
    } else {
      const handlers = this.handlers[eventName] || [];
      this.handlers[eventName] = handlers.filter(obj => obj.handler !== handler);
    }
  }

  emit(eventName, ...rest) {
    const handlers = this.handlers[eventName] || [];

    handlers.forEach(({ handler, context }) => handler.apply(context, rest));
  }
}

export default Events;
