require 'rails_helper'

describe Idv::Actions::VerifyDocumentStatusAction do
  include IdvHelper

  let(:user) { build(:user) }
  let(:controller) { instance_double(Idv::DocAuthController) }
  let(:session) { { 'idv/doc_auth' => {} } }
  let(:flow) { Idv::Flows::DocAuthFlow.new(controller, session, 'idv/doc_auth') }
  let(:fake_analytics) { FakeAnalytics.new }

  subject { described_class.new(flow) }

  describe '#call' do
    it 'calls analytics if timed out from no document capture session' do
      expect(controller).to receive(:analytics).and_return(fake_analytics).twice
      response = subject.call

      expect(fake_analytics).to have_logged_event(
        Analytics::DOC_AUTH_ASYNC,
        error: 'failed to load document_capture_session',
        uuid: nil,
      )
    end

    it 'calls analytics if timed out from no result in document capture session' do
      document_capture_session = DocumentCaptureSession.new(uuid: 'uuid', result_id: 'result_id')

      expect(subject).to receive(:document_capture_session).and_return(document_capture_session).
        at_least(:once)
      expect(controller).to receive(:analytics).and_return(fake_analytics).twice
      response = subject.call

      expect(fake_analytics).to have_logged_event(
        Analytics::DOC_AUTH_ASYNC,
        error: 'failed to load async result',
        uuid: document_capture_session.uuid,
        result_id: document_capture_session.result_id,
      )
    end
  end
end
