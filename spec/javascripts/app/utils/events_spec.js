const Events = require('../../../../app/javascript/app/utils/events').default;
/*eslint-disable */
const sinon = require('sinon');
/*eslint-enable */

describe('Events', () => {
  const myEvent = 'super.event';
  const dummyHandler = sinon.stub();
  let events;

  beforeEach(() => {
    events = new Events();
  });

  it('maintains a map of handler objects', () => {
    expect(events.handlers).not.to.be.undefined();
    expect(events.handlers).to.be.an('object');
  });

  describe('#on', () => {
    it('does nothing if an event name is not supplied', () => {
      const initialHandlerLen = Object.keys(events.handlers).length;
      events.on();

      expect(Object.keys(events.handlers).length).to.equal(initialHandlerLen);
    });

    it('adds handler object to event key when name and function supplied', () => {
      events.on(myEvent, dummyHandler);

      const clickHandlers = events.handlers[myEvent];

      expect(clickHandlers.length).to.equal(1);
      expect(clickHandlers[0]).to.be.an('object');
      expect(clickHandlers[0].handler).to.equal(dummyHandler);
    });

    it('stores the context of the handler when supplied', () => {
      class FakeClass { contructor() { this.thing = 'fake'; } }

      const fake = new FakeClass();

      events.on(myEvent, dummyHandler, fake);

      expect(events.handlers[myEvent][0].context instanceof FakeClass).to.be.true();
    });
  });

  describe('#off', () => {
    it('deletes all handlers if no event name is supplied', () => {
      events.on(myEvent, dummyHandler);
      events.off();

      expect(events.handlers[myEvent].length).to.equal(0);
    });

    it('deletes all events registered for a given even when one is supplied', () => {
      const otherEvent = 'other.event';

      events.on(myEvent, dummyHandler);
      events.on(otherEvent, function() {});

      events.off(myEvent);

      expect(events.handlers[otherEvent].length).to.equal(1);
    });

    it('deletes the specific handler supplied', () => {
      const anotherStub = sinon.stub();

      events.on(myEvent, dummyHandler);
      events.on(myEvent, anotherStub);

      events.off(myEvent, dummyHandler);

      expect(events.handlers[myEvent].length).to.equal(1);
      expect(events.handlers[myEvent][0].handler).to.equal(anotherStub);
    });
  });

  describe('#emit', () => {
    it('calls each handler registered to an event', () => {
      events.on(myEvent, dummyHandler);
      events.emit(myEvent);

      expect(dummyHandler.calledOnce).to.be.true();
    });
  });
});
