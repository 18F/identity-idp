require 'rails_helper'

describe Idv::Actions::VerifyDocumentStatusAction do
  include IdvHelper

  let(:user) { build(:user) }
  let(:controller) do
    instance_double(Idv::DocAuthController, url_options: {}, analytics: analytics)
  end
  let(:session) { { 'idv/doc_auth' => {} } }
  let(:flow) { Idv::Flows::DocAuthFlow.new(controller, session, 'idv/doc_auth') }
  let(:analytics) { FakeAnalytics.new }

  subject { described_class.new(flow) }

  describe '#call' do
    it 'calls analytics if timed out from no document capture session' do
      response = subject.call

      expect(analytics).to have_logged_event(Analytics::PROOFING_DOCUMENT_TIMEOUT, {})
      expect(analytics).to have_logged_event(
        Analytics::DOC_AUTH_ASYNC,
        error: 'failed to load verify_document_capture_session',
        uuid: nil,
      )
    end

    it 'calls analytics if timed out from no result in document capture session' do
      verify_document_capture_session = DocumentCaptureSession.new(
        uuid: 'uuid',
        result_id: 'result_id',
      )

      expect(subject).to receive(:verify_document_capture_session).
        and_return(verify_document_capture_session).at_least(:once)
      response = subject.call

      expect(analytics).to have_logged_event(Analytics::PROOFING_DOCUMENT_TIMEOUT, {})
      expect(analytics).to have_logged_event(
        Analytics::DOC_AUTH_ASYNC,
        error: 'failed to load async result',
        uuid: verify_document_capture_session.uuid,
        result_id: verify_document_capture_session.result_id,
      )
    end
  end
end
