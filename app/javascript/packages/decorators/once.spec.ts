import sinon from 'sinon';
import { once } from './once';

describe('once', () => {
  let spy: sinon.SinonSpy;

  beforeEach(() => {
    spy = sinon.spy();
  });

  context('getter', () => {
    class Example {
      expectedResult?: any;

      constructor(expectedResult?: any) {
        this.expectedResult = expectedResult;
      }

      @once()
      get foo() {
        spy();
        return this.expectedResult;
      }
    }

    it('returns the value of the original function', () => {
      const example = new Example();
      const result = example.foo;

      expect(result).to.equal(example.expectedResult);
    });

    it('returns the value of the original function, once', () => {
      const example = new Example();
      const result1 = example.foo;
      const result2 = example.foo;

      expect(result1).to.equal(example.expectedResult);
      expect(result2).to.equal(example.expectedResult);
      expect(spy).to.have.been.calledOnce();
    });

    it('returns the value of the original function, once per instance', () => {
      const example1 = new Example(1);
      const result1 = example1.foo;
      const result2 = example1.foo;
      const example2 = new Example(2);
      const result3 = example2.foo;
      const result4 = example2.foo;

      expect(result1).to.equal(example1.expectedResult);
      expect(result2).to.equal(example1.expectedResult);
      expect(result3).to.equal(example2.expectedResult);
      expect(result4).to.equal(example2.expectedResult);
      expect(spy).to.have.been.calledTwice();
    });
  });

  context('function', () => {
    class Example {
      expectedResult?: any;

      constructor(expectedResult?: any) {
        this.expectedResult = expectedResult;
      }

      @once()
      getFoo() {
        spy();
        return this.expectedResult;
      }
    }

    it('returns the value of the original function', () => {
      const example = new Example();
      const result = example.getFoo();

      expect(result).to.equal(example.expectedResult);
    });

    it('returns the value of the original function, once', () => {
      const example = new Example();
      const result1 = example.getFoo();
      const result2 = example.getFoo();

      expect(result1).to.equal(example.expectedResult);
      expect(result2).to.equal(example.expectedResult);
      expect(spy).to.have.been.calledOnce();
    });

    it('returns the value of the original function, once per instance', () => {
      const example1 = new Example(1);
      const result1 = example1.getFoo();
      const result2 = example1.getFoo();
      const example2 = new Example(2);
      const result3 = example2.getFoo();
      const result4 = example2.getFoo();

      expect(result1).to.equal(example1.expectedResult);
      expect(result2).to.equal(example1.expectedResult);
      expect(result3).to.equal(example2.expectedResult);
      expect(result4).to.equal(example2.expectedResult);
      expect(spy).to.have.been.calledTwice();
    });
  });
});
