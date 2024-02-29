import userEvent from '@testing-library/user-event';
import { within } from '@testing-library/react';
import sinon from 'sinon';
import { expect } from 'chai';
import { t } from '@18f/identity-i18n';
import {
  DeviceContext,
  UploadContextProvider,
  FailedCaptureAttemptsContextProvider,
  SelfieCaptureEnabledContext,
} from '@18f/identity-document-capture';
import DocumentsStep from '@18f/identity-document-capture/components/documents-step';
import { composeComponents } from '@18f/identity-compose-components';
import { render } from '../../../support/document-capture';
import { getFixtureFile } from '../../../support/file';

describe('document-capture/components/documents-step', () => {
  it('renders with only front and back inputs by default', () => {
    const { getByLabelText, queryByLabelText } = render(<DocumentsStep />);

    const front = getByLabelText('doc_auth.headings.document_capture_front');
    const back = getByLabelText('doc_auth.headings.document_capture_back');
    const selfie = queryByLabelText('doc_auth.headings.document_capture_selfie');

    expect(front).to.be.ok();
    expect(back).to.be.ok();
    expect(selfie).to.not.exist();
  });

  it('calls onChange callback with uploaded image', async () => {
    const onChange = sinon.stub();
    const { getByLabelText } = render(
      <FailedCaptureAttemptsContextProvider
        maxCaptureAttemptsBeforeNativeCamera={3}
        maxSubmissionAttemptsBeforeNativeCamera={3}
      >
        <DocumentsStep onChange={onChange} />,
      </FailedCaptureAttemptsContextProvider>,
    );
    const file = await getFixtureFile('doc_auth_images/id-back.jpg');

    await Promise.all([
      new Promise((resolve) => onChange.callsFake(resolve)),
      userEvent.upload(getByLabelText('doc_auth.headings.document_capture_front'), file),
    ]);
    expect(onChange).to.have.been.calledWith({
      front: file,
      front_image_metadata: sinon.match(/^\{.+\}$/),
    });
  });

  it('renders device-specific instructions', () => {
    let { getByText } = render(
      <DeviceContext.Provider value={{ isMobile: true }}>
        <DocumentsStep />
      </DeviceContext.Provider>,
    );

    expect(() => getByText('doc_auth.tips.document_capture_id_text4')).to.throw();

    getByText = render(<DocumentsStep />).getByText;

    expect(() => getByText('doc_auth.tips.document_capture_id_text4')).not.to.throw();
  });

  it('renders the hybrid flow warning if the flow is hybrid', () => {
    const { getByText } = render(
      <DeviceContext.Provider value={{ isMobile: true }}>
        <UploadContextProvider flowPath="hybrid">
          <DocumentsStep />
        </UploadContextProvider>
      </DeviceContext.Provider>,
    );
    const expectedText = t('doc_auth.hybrid_flow_warning.explanation_non_sp_html');

    expect(getByText(expectedText)).to.exist();
  });

  it('does not render the hybrid flow warning if the flow is standard (default)', () => {
    const { queryByText } = render(
      <DeviceContext.Provider value={{ isMobile: true }}>
        <UploadContextProvider flowPath="standard">
          <DocumentsStep />
        </UploadContextProvider>
      </DeviceContext.Provider>,
    );
    const notExpectedText = t('doc_auth.hybrid_flow_warning.explanation_non_sp_html');

    expect(queryByText(notExpectedText)).to.not.exist();
  });

  context('selfie capture', () => {
    it('renders with front, back, and selfie inputs when selfieCaptureEnabled is true', () => {
      const App = composeComponents(
        [
          SelfieCaptureEnabledContext.Provider,
          {
            value: {
              selfieCaptureEnabled: true,
            },
          },
        ],
        [DocumentsStep],
      );
      const { getAllByRole, getByText, getByRole, getByLabelText, queryByLabelText } = render(
        <App />,
      );

      const front = getByLabelText('doc_auth.headings.document_capture_front');
      const back = getByLabelText('doc_auth.headings.document_capture_back');
      const selfie = queryByLabelText('doc_auth.headings.document_capture_selfie');
      const pageHeader = getByRole('heading', {
        name: 'doc_auth.headings.document_capture_with_selfie',
        level: 1,
      });
      const idHeader = getByRole('heading', {
        name: '1. doc_auth.headings.document_capture_subheader_id',
        level: 2,
      });
      const selfieHeader = getByRole('heading', {
        name: '2. doc_auth.headings.document_capture_subheader_selfie',
        level: 2,
      });
      expect(front).to.be.ok();
      expect(back).to.be.ok();
      expect(selfie).to.be.ok();
      expect(pageHeader).to.be.ok();
      expect(idHeader).to.be.ok();
      expect(selfieHeader).to.be.ok();

      const tipListHeader = getByText('doc_auth.tips.document_capture_selfie_selfie_text');
      expect(tipListHeader).to.be.ok();
      const lists = getAllByRole('list');
      const tipList = lists[1];
      expect(tipList).to.be.ok();
      const tipListItem = within(tipList).getAllByRole('listitem');
      tipListItem.forEach((li, idx) => {
        expect(li.textContent).to.equals(`doc_auth.tips.document_capture_selfie_text${idx + 1}`);
      });
    });
  });

  it('renders with front, back when selfieCaptureEnabled is false', () => {
    const App = composeComponents(
      [
        SelfieCaptureEnabledContext.Provider,
        {
          value: {
            selfieCaptureEnabled: false,
          },
        },
      ],
      [DocumentsStep],
    );
    const { getByRole, getByLabelText } = render(<App />);

    const front = getByLabelText('doc_auth.headings.document_capture_front');
    const back = getByLabelText('doc_auth.headings.document_capture_back');
    const pageHeader = getByRole('heading', {
      name: 'doc_auth.headings.document_capture',
      level: 1,
    });
    const idHeader = getByRole('heading', {
      name: 'doc_auth.headings.document_capture_subheader_id',
      level: 2,
    });

    expect(front).to.be.ok();
    expect(back).to.be.ok();
    expect(pageHeader).to.be.ok();
    expect(idHeader).to.be.ok();
  });
});
