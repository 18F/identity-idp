import {
  ServiceProviderContextProvider,
  UploadContextProvider,
  InPersonContext,
} from '@18f/identity-document-capture';
import { FlowContext } from '@18f/identity-verify-flow';
import httpUpload from '@18f/identity-document-capture/services/upload';
import { useSteps } from '@18f/identity-document-capture/hooks/use-steps';
import { renderHook } from '@testing-library/react-hooks';

function Providers({ children, inPersonURLPresent = true, flowPathIsHybrid = false }) {
  const flowPath = flowPathIsHybrid ? 'hybrid' : 'not-hybrid';
  const inPersonURL = inPersonURLPresent ? '/in_person' : undefined;
  const endpoint = '/upload';
  const cancelURL = '/cancel';
  const currentStep = 'document_capture';

  return (
    <UploadContextProvider upload={httpUpload} endpoint={endpoint} flowPath={flowPath}>
      <ServiceProviderContextProvider value={{ isLivenessRequired: false }}>
        <FlowContext.Provider value={{ cancelURL, currentStep }}>
          <InPersonContext.Provider value={{ inPersonURL }}>{children}</InPersonContext.Provider>
        </FlowContext.Provider>
      </ServiceProviderContextProvider>
    </UploadContextProvider>
  );
}

// This allows using renderHook and passing props to the Provider components
// https://testing-library.com/docs/react-testing-library/api/#renderhook-options
const createWrapper =
  (Wrapper, props) =>
  ({ children }) => <Wrapper {...props}>{children}</Wrapper>;

describe('document-capture/hooks/use-steps', () => {
  it('returns only the documents step when there is no submission error', () => {
    const { result } = renderHook(() => useSteps(undefined), {
      wrapper: createWrapper(Providers, {}),
    });

    const stepOneName = result.current[0].name;
    expect(stepOneName).to.equal('documents');
    const numberOfSteps = result.current.length;
    expect(numberOfSteps).to.equal(1);
  });

  describe('not in hybrid flow when there is a submission error', () => {
    it('returns review, prepare, location steps', () => {
      const { result } = renderHook(() => useSteps('submission-error'), {
        wrapper: createWrapper(Providers, {}),
      });
      const stepOneName = result.current[0].name;
      expect(stepOneName).to.equal('review');
      const stepTwoName = result.current[1].name;
      expect(stepTwoName).to.equal('prepare');
      const stepThreeName = result.current[2].name;
      expect(stepThreeName).to.equal('location');
      const numberOfSteps = result.current.length;
      expect(numberOfSteps).to.equal(3);
    });

    it('returns only the review step when no inPersonURL is present', () => {
      const { result } = renderHook(() => useSteps('submission-error'), {
        wrapper: createWrapper(Providers, {
          inPersonURLPresent: false,
        }),
      });
      const stepOneName = result.current[0].name;
      expect(stepOneName).to.equal('review');
      const numberOfSteps = result.current.length;
      expect(numberOfSteps).to.equal(1);
    });
  });

  describe('in hybrid flow when there is a submission error', () => {
    it('returns review, prepare, location, and switch_back steps', () => {
      const { result } = renderHook(() => useSteps('submission-error'), {
        wrapper: createWrapper(Providers, { flowPathIsHybrid: true }),
      });
      const stepOneName = result.current[0].name;
      expect(stepOneName).to.equal('review');
      const stepTwoName = result.current[1].name;
      expect(stepTwoName).to.equal('prepare');
      const stepThreeName = result.current[2].name;
      expect(stepThreeName).to.equal('location');
      const stepFourName = result.current[3].name;
      expect(stepFourName).to.equal('switch_back');
      const numberOfSteps = result.current.length;
      expect(numberOfSteps).to.equal(4);
    });

    it('returns only the review step when no inPersonURL is present', () => {
      it('returns review, prepare, location, and switch_back steps', () => {
        const { result } = renderHook(() => useSteps('submission-error'), {
          wrapper: createWrapper(Providers, { flowPathIsHybrid: true, inPersonURLPresent: false }),
        });
        const stepOneName = result.current[0].name;
        expect(stepOneName).to.equal('review');
        const numberOfSteps = result.current.length;
        expect(numberOfSteps).to.equal(1);
      });
    });
  });
});
