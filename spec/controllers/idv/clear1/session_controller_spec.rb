require 'rails_helper'

RSpec.describe Idv::Clear1::SessionController do
  include FlowPolicyHelper

  let(:idv_vendor) { Idp::Constants::Vendors::CLEAR1 }
  let(:vendor_switching_enabled) { true }
  let(:user) { create(:user) }
  let(:clear1_success) { true }
  let(:clear1_enabled) { true }
  let(:idv_clear1_project_id) { 'fav-proj-id' }
  let(:token) { 'crystal_clear1_token' }
  let(:state) { SecureRandom.uuid }
  let(:idv_clear1_api_base_url) { 'https://fake-clear1.test' }
  let(:clear_session_endpoint) do
    "#{idv_clear1_api_base_url}/v1/verification_sessions"
  end
  let(:clear1_status) { 200 }
  let(:document_capture_session) do
    create(
      :document_capture_session,
      user:,
      requested_at: Time.zone.now,
    )
  end
  let(:uuid_pattern) { /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/i }

  before do
    allow(IdentityConfig.store).to receive_messages(
      idv_clear1_api_base_url:,
      idv_clear1_project_id:,
    )

    user_session = {}
    allow(subject).to receive(:user_session).and_return(user_session)

    subject.idv_session.tap do |idv_session|
      idv_session.document_capture_session_uuid = document_capture_session.uuid
      idv_session.flow_path = 'standard'
      idv_session.clear1_enabled = clear1_enabled
    end

    stub_up_to(:hybrid_handoff, idv_session: subject.idv_session)

    stub_analytics
  end

  describe '#step_info' do
    it 'returns a valid StepInfo object' do
      expect(described_class.step_info).to be_valid
    end

    describe '#undo_step' do
      let(:idv_session) do
        Idv::Session.new(
          user_session: {},
          current_user: user,
          service_provider: nil,
        ).tap do |idv_session|
          idv_session.pii_from_doc = { name: 'test' }
          idv_session.doc_auth_vendor = Idp::Constants::Vendors::CLEAR1
          idv_session.source_check_vendor = Idp::Constants::Vendors::CLEAR1
        end
      end

      it 'resets relevant fields on idv_session to nil' do
        described_class.step_info.undo_step.call(idv_session:, user:)
        aggregate_failures do
          expect(idv_session.pii_from_doc).to be(nil)
          expect(idv_session.doc_auth_vendor).to be(nil)
          expect(idv_session.source_check_vendor).to be(nil)
        end
      end
    end
  end

  describe 'before_actions' do
    it 'includes authentication before_action' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated,
      )
    end
  end

  describe '#show' do
    let(:response_body) { { token: }.compact }

    before do
      stub_request(:post, clear_session_endpoint)
        .with(body: hash_including(
          project_id: idv_clear1_project_id,
          redirect_url: /#{idv_clear1_session_update_url}\?state=#{uuid_pattern}/,
          custom_fields: { user_uuid: user.uuid },
        ))
        .to_return(
          status: clear1_status,
          body: JSON.generate(response_body),
        )

      stub_sign_in(user)
    end

    context 'happy path' do
      let(:clear1_app_url) { "#{idv_clear1_api_base_url}/verify?token=#{token}" }

      it 'sets clear token in idv session' do
        get(:show)

        expect(subject.idv_session.clear1_verification_token).to eq(token)
      end

      it 'sets clear state in idv session' do
        get(:show)

        expect(subject.idv_session.clear1_verification_state).to match(uuid_pattern)
      end

      context 'when the request class is called' do
        let(:request_class) { Proofing::Clear1::Requests::SessionRequest }
        before do
          allow(request_class).to receive(:new).and_call_original
        end
        it 'sets clear token in idv session' do
          expect(request_class).to receive(:new)
            .with(
              user_uuid: user.uuid,
              redirect_url: idv_clear1_session_update_url,
            )
          get(:show)
        end
      end

      xit 'logs correct info' do
        get(:show)

        expect(@analytics).to have_logged_event(
          :idv_clear1_session_request_submitted,
        )
      end

      it 'sets DocumentCaptureSession doc_auth_vendor value' do
        get(:show)

        expect(subject.document_capture_session.reload.doc_auth_vendor)
          .to eq(Idp::Constants::Vendors::CLEAR1)
      end

      context 'renders the interstital page' do
        render_views

        it 'response includes the clear1 app url' do
          get(:show)
          expect(response).to have_http_status 200
        end
      end
    end

    context 'no token in the clear response' do
      let(:token) { nil }

      it 'redirects to the errors page' do
        get(:show)

        expect(response).to redirect_to(idv_hybrid_handoff_path)
      end
    end

    context 'when clear1 is disabled' do
      let(:clear1_enabled) { false }

      it 'the webhook route does not exist' do
        get(:show)

        expect(response).to be_not_found
      end
    end

    context 'when clear1 error encountered' do
      let(:clear1_status) { 500 }
      it 'redirects to hybrid handoff page' do
        get(:show)

        expect(response).to redirect_to(idv_hybrid_handoff_path)
      end
    end
  end

  describe '#update' do
    before do
      stub_sign_in(user)
      subject.idv_session.clear1_verification_token = token
      subject.idv_session.clear1_verification_state = SecureRandom.uuid
    end

    context 'when clear1 is disabled' do
      let(:clear1_enabled) { false }

      it 'the route does not exist' do
        get(:update)
        expect(response).to be_not_found
      end
    end
  end
end
