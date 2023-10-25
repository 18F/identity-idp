import {
  ServiceProviderContextProvider,
  UploadContextProvider,
  InPersonContext,
} from '@18f/identity-document-capture';
import { FlowContext } from '@18f/identity-verify-flow';
import httpUpload from '@18f/identity-document-capture/services/upload';
import { useSteps } from '@18f/identity-document-capture/hooks/use-steps';
import { render } from '../../../support/document-capture';

function TestComponent({ submissionError }) {
  const steps = useSteps(submissionError);
  const stepElements = steps.map((step) => <div key={step.name}>{step.name}</div>);
  return stepElements;
}

const setup = ({ submissionError, inPersonURLPresent = true, flowPathIsHybrid = false }) => {
  const flowPath = flowPathIsHybrid ? 'hybrid' : 'not-hybrid';
  const inPersonURL = inPersonURLPresent ? '/in_person' : undefined;
  const endpoint = '/upload';
  const cancelURL = '/cancel';
  const currentStep = 'document_capture';

  const { queryByText, getByText } = render(
    <UploadContextProvider upload={httpUpload} endpoint={endpoint} flowPath={flowPath}>
      <ServiceProviderContextProvider value={{ isLivenessRequired: false }}>
        <FlowContext.Provider value={{ cancelURL, currentStep }}>
          <InPersonContext.Provider value={{ inPersonURL }}>
            <TestComponent submissionError={submissionError} />
          </InPersonContext.Provider>
        </FlowContext.Provider>
      </ServiceProviderContextProvider>
    </UploadContextProvider>,
  );

  return { getByText, queryByText };
};

describe('document-capture/hooks/use-steps', () => {
  it('returns only the documents step when there is no submission error', () => {
    const { queryByText } = setup({});
    expect(queryByText('documents')).to.exist();
    expect(queryByText('review')).not.to.exist();
    expect(queryByText('location')).not.to.exist();
    expect(queryByText('prepare')).not.to.exist();
    expect(queryByText('switch_back')).not.to.exist();
  });

  describe('not in hybrid flow when there is a submission error', () => {
    it('returns review, prepare, location steps', () => {
      const { queryByText } = setup({ submissionError: 'submissionError' });
      expect(queryByText('documents')).not.to.exist();
      expect(queryByText('review')).to.exist();
      expect(queryByText('location')).to.exist();
      expect(queryByText('prepare')).to.exist();
      expect(queryByText('switch_back')).not.to.exist();
    });

    it('returns only the review step when no inPersonURL is present', () => {
      const { queryByText } = setup({
        submissionError: 'submissionError',
        inPersonURLPresent: false,
      });
      expect(queryByText('documents')).not.to.exist();
      expect(queryByText('review')).to.exist();
      expect(queryByText('location')).not.to.exist();
      expect(queryByText('prepare')).not.to.exist();
      expect(queryByText('switch_back')).not.to.exist();
    });
  });

  describe('in hybrid flow when there is a submission error', () => {
    it('returns review, prepare, location, and switch_back steps', () => {
      const { queryByText } = setup({
        submissionError: 'submissionError',
        flowPathIsHybrid: true,
      });
      expect(queryByText('documents')).not.to.exist();
      expect(queryByText('review')).to.exist();
      expect(queryByText('location')).to.exist();
      expect(queryByText('prepare')).to.exist();
      expect(queryByText('switch_back')).to.exist();
    });
    it('returns review and switch_back steps when no inPersonURL is present', () => {
      it('returns review, prepare, location, and switch_back steps', () => {
        const { queryByText } = setup({
          submissionError: 'submissionError',
          flowPathIsHybrid: true,
          inPersonURLPresent: false,
        });
        expect(queryByText('documents')).not.to.exist();
        expect(queryByText('review')).to.exist();
        expect(queryByText('location')).not.to.exist();
        expect(queryByText('prepare')).not.to.exist();
        expect(queryByText('switch_back')).to.exist();
      });
    });
  });
});
