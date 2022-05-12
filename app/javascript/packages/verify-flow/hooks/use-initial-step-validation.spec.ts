import sinon from 'sinon';
import { renderHook } from '@testing-library/react-hooks';
import { useDefineProperty } from '@18f/identity-test-helpers';
import { FormStep } from '@18f/identity-form-steps';
import useInitialStepValidation from './use-initial-step-validation';

const TEST_BASE_PATH = '/step/';
const STEPS = [{ name: 'one' }, { name: 'two' }, { name: 'three' }] as FormStep[];

describe('useInitialStepValidation', () => {
  const defineProperty = useDefineProperty();

  context('with no path param', () => {
    beforeEach(() => {
      defineProperty(window, 'location', {
        value: {
          pathname: TEST_BASE_PATH,
        },
      });
    });

    it('returns the first step', () => {
      const { result } = renderHook(() => useInitialStepValidation(TEST_BASE_PATH, STEPS));
      const [initialStep] = result.current;

      expect(initialStep).to.equal(STEPS[0].name);
    });
  });

  context('with path param exceeding progress', () => {
    beforeEach(() => {
      defineProperty(window, 'location', {
        value: {
          pathname: TEST_BASE_PATH + STEPS[1].name,
        },
      });
    });

    it('returns furthest step progress', () => {
      const { result } = renderHook(() => useInitialStepValidation(TEST_BASE_PATH, STEPS));
      const [initialStep] = result.current;

      expect(initialStep).to.equal(STEPS[0].name);
    });
  });

  context('with path param not exceeding progress', () => {
    beforeEach(() => {
      defineProperty(window, 'location', {
        value: {
          pathname: TEST_BASE_PATH + STEPS[1].name,
        },
      });

      defineProperty(global, 'sessionStorage', {
        value: {
          getItem: sinon.stub().withArgs('completedStep').returns(STEPS[0].name),
        },
      });
    });

    it('returns path param', () => {
      const { result } = renderHook(() => useInitialStepValidation(TEST_BASE_PATH, STEPS));
      const [initialStep] = result.current;

      expect(initialStep).to.equal(STEPS[1].name);
    });
  });
});
