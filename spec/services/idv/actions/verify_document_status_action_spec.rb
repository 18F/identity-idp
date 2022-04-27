require 'rails_helper'

describe Idv::Actions::VerifyDocumentStatusAction do
  include IdvHelper

  let(:user) { create(:user) }
  let(:session) { { 'idv/doc_auth' => {} } }
  let(:controller) do
    instance_double(Idv::DocAuthController, url_options: {}, session: session, analytics: analytics)
  end
  let(:flow) { Idv::Flows::DocAuthFlow.new(controller, session, 'idv/doc_auth') }
  let(:analytics) { FakeAnalytics.new }
  let(:result) do
    { doc_auth_result: 'Passed', success: true, errors: {}, exception: nil, billed: true }
  end
  let(:pii) do
    {
      first_name: Faker::Name.first_name,
      last_name: Faker::Name.last_name,
      dob: Faker::Date.birthday(min_age: IdentityConfig.store.idv_min_age_years + 1).to_s,
      state: Faker::Address.state_abbr,
    }
  end
  let(:done) { true }
  let(:async_state) { OpenStruct.new(result: result, pii: pii, pii_from_doc: pii, 'done?' => done) }

  subject { described_class.new(flow) }

  describe '#call' do
    context 'successful async result' do
      before do
        allow(subject).to receive(:async_state).and_return(async_state)
        allow(subject).to receive(:add_cost).and_return(true)
        allow(subject).to receive(:current_user).and_return(user)
      end

      it 'calls analytics to log the successful event' do
        subject.call

        expect(analytics).to have_logged_event(
          Analytics::IDV_DOC_AUTH_SUBMITTED_PII_VALIDATION,
          success: true,
          errors: {},
        )
      end
    end

    it 'calls analytics if missing from no document capture session' do
      subject.call

      expect(analytics).to have_logged_event('Proofing Document Result Missing', {})
      expect(analytics).to have_logged_event(
        'Doc Auth Async',
        error: 'failed to load verify_document_capture_session',
        uuid: nil,
      )
    end

    it 'calls analytics if missing from no result in document capture session' do
      verify_document_capture_session = DocumentCaptureSession.new(
        uuid: 'uuid',
        result_id: 'result_id',
        user: create(:user),
      )

      expect(subject).to receive(:verify_document_capture_session).
        and_return(verify_document_capture_session).at_least(:once)
      subject.call

      expect(analytics).to have_logged_event('Proofing Document Result Missing', {})
      expect(analytics).to have_logged_event(
        'Doc Auth Async',
        error: 'failed to load async result',
        uuid: verify_document_capture_session.uuid,
        result_id: verify_document_capture_session.result_id,
      )
    end
  end
end
