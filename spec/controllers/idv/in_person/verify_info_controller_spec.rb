require 'rails_helper'

RSpec.describe Idv::InPerson::VerifyInfoController do
  include IdvHelper

  let(:pii_from_user) { Idp::Constants::MOCK_IDV_APPLICANT_SAME_ADDRESS_AS_ID.dup }
  let(:flow_session) do
    { 'document_capture_session_uuid' => 'fd14e181-6fb1-4cdc-92e0-ef66dad0df4e',
      :pii_from_user => pii_from_user,
      :flow_path => 'standard' }
  end

  let(:user) { build(:user, :with_phone, with: { phone: '+1 (415) 555-0130' }) }
  let(:service_provider) { create(:service_provider) }

  let(:ab_test_args) do
    { sample_bucket1: :sample_value1, sample_bucket2: :sample_value2 }
  end

  before do
    allow(subject).to receive(:flow_session).and_return(flow_session)
    stub_sign_in(user)
    subject.idv_session.ssn = Idp::Constants::MOCK_IDV_APPLICANT_SAME_ADDRESS_AS_ID[:ssn]
    allow(subject).to receive(:ab_test_analytics_buckets).and_return(ab_test_args)
  end

  describe 'before_actions' do
    it 'includes authentication before_action' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated,
      )
    end

    it 'includes outage before_action' do
      expect(subject).to have_actions(
        :before,
        :check_for_mail_only_outage,
      )
    end

    it 'confirms ssn step complete' do
      expect(subject).to have_actions(
        :before,
        :confirm_ssn_step_complete,
      )
    end

    it 'confirms verify step needed' do
      expect(subject).to have_actions(
        :before,
        :confirm_verify_info_step_needed,
      )
    end
  end

  before do
    stub_analytics
    stub_attempts_tracker
  end

  describe '#show' do
    let(:analytics_name) { 'IdV: doc auth verify visited' }
    let(:analytics_args) do
      {
        analytics_id: 'In Person Proofing',
        flow_path: 'standard',
        irs_reproofing: false,
        step: 'verify',
      }.merge(ab_test_args)
    end

    it 'renders the show template' do
      get :show

      expect(response).to render_template :show
    end

    it 'sends analytics_visited event' do
      get :show

      expect(@analytics).to have_logged_event(
        'IdV: doc auth verify visited',
        hash_including(**analytics_args, same_address_as_id: true),
      )
    end

    context 'when done' do
      let(:review_status) { 'review' }
      let(:async_state) { instance_double(ProofingSessionAsyncResult) }
      let(:adjudicated_result) do
        {
          context: {
            stages: {
              threatmetrix: {
                transaction_id: 1,
                review_status: review_status,
                response_body: {
                  tmx_summary_reason_code: ['Identity_Negative_History'],
                },
              },
            },
          },
          errors: {},
          exception: nil,
          success: true,
          threatmetrix_review_status: review_status,
        }
      end
      it 'logs proofing results with analytics_id' do
        allow(controller).to receive(:load_async_state).and_return(async_state)
        allow(async_state).to receive(:done?).and_return(true)
        allow(async_state).to receive(:result).and_return(adjudicated_result)

        get :show

        expect(@analytics).to have_logged_event(
          'IdV: doc auth verify proofing results',
          hash_including(**analytics_args, success: true),
        )
      end
    end
  end

  describe '#update' do
    let(:pii_from_user) { Idp::Constants::MOCK_IDV_APPLICANT_STATE_ID_ADDRESS.dup }
    let(:enrollment) { InPersonEnrollment.new }
    before do
      allow(user).to receive(:establishing_in_person_enrollment).and_return(enrollment)
    end

    it 'redirects to the expected page' do
      put :update

      expect(response).to redirect_to idv_in_person_verify_info_url
    end

    it 'captures state id address fields in the pii' do
      expect(Idv::Agent).to receive(:new).
        with(Idp::Constants::MOCK_IDV_APPLICANT_STATE_ID_ADDRESS.merge(uuid_prefix: nil)).
        and_call_original
      put :update
    end
  end
end
