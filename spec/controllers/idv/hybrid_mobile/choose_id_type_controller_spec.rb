require 'rails_helper'

RSpec.describe Idv::HybridMobile::ChooseIdTypeController do
  let(:idv_vendor) { Idp::Constants::Vendors::MOCK }
  let(:user) { create(:user) }
  let(:passport_status) { nil }

  let!(:document_capture_session) do
    create(
      :document_capture_session,
      user:,
      requested_at: Time.zone.now,
      doc_auth_vendor: idv_vendor,
      passport_status:,
    )
  end

  let(:document_capture_session_uuid) { document_capture_session&.uuid }
  let(:session_uuid) { document_capture_session.uuid }
  let(:proofing_device_hybrid_profiling) { :disabled }
  let(:hybrid_mobile_tmx_processed_percent) { 100 }

  before do
    stub_request(:get, IdentityConfig.store.dos_passport_composite_healthcheck_endpoint)
      .to_return({ status: 200, body: { status: 'UP' }.to_json })
    stub_analytics
    session[:doc_capture_user_id] = user&.id
    session[:document_capture_session_uuid] = document_capture_session_uuid

    allow(IdentityConfig.store).to receive(:doc_auth_vendor).and_return(idv_vendor)
    allow(IdentityConfig.store).to receive(:doc_auth_vendor_default).and_return(idv_vendor)
    allow(controller).to receive(:document_capture_session).and_return(document_capture_session)
    allow(IdentityConfig.store).to receive(:proofing_device_hybrid_profiling)
      .and_return(proofing_device_hybrid_profiling)
    allow(IdentityConfig.store).to receive(:hybrid_mobile_tmx_processed_percent)
      .and_return(hybrid_mobile_tmx_processed_percent)
  end

  describe 'before actions' do
    it 'includes correct before_actions' do
      expect(subject).to have_actions(
        :before,
        :check_valid_document_capture_session,
        :override_csp_for_threat_metrix,
      )
    end
  end

  describe '#show' do
    subject(:response) { get :show }

    it 'renders the show template' do
      get :show

      expect(response).to render_template('idv/shared/choose_id_type')
    end

    context 'with threatmetrix disabled' do
      let(:proofing_device_hybrid_profiling) { :disabled }

      it 'does not override CSPs for ThreatMetrix' do
        expect(controller).not_to receive(:override_csp_for_threat_metrix)

        response
      end
    end

    context 'with threatmetrix enabled' do
      let(:tmx_session_id) { '1234' }
      let(:proofing_device_hybrid_profiling) { :enabled }
      before do
        allow(IdentityConfig.store).to receive(:proofing_device_hybrid_profiling)
          .and_return(:enabled)
        allow(IdentityConfig.store).to receive(:lexisnexis_threatmetrix_org_id).and_return('org1')
        allow(IdentityConfig.store).to receive(:lexisnexis_threatmetrix_mock_enabled)
          .and_return(false)
        controller.session[:hybrid_flow_threatmetrix_session_id] = tmx_session_id
      end

      it 'renders new valid request' do
        tmx_url = 'https://h.online-metrix.net/fp'
        expect(controller).to receive(:render).with(
          'idv/shared/choose_id_type',
          locals: hash_including(
            threatmetrix_session_id: tmx_session_id,
            threatmetrix_javascript_urls:
              ["#{tmx_url}/tags.js?org_id=org1&session_id=#{tmx_session_id}"],
            threatmetrix_iframe_url:
              "#{tmx_url}/tags?org_id=org1&session_id=#{tmx_session_id}",
          ),
        ).and_call_original

        expect(response).to render_template('idv/shared/choose_id_type')
      end

      it 'overrides CSPs for ThreatMetrix' do
        expect(controller).to receive(:override_csp_for_threat_metrix)

        response
      end
    end

    context 'passport is available' do
      let(:analytics_name) { :idv_doc_auth_choose_id_type_visited }
      let(:analytics_args) do
        {
          step: 'hybrid_choose_id_type',
          analytics_id: 'Doc Auth',
          flow_path: 'hybrid',
        }
      end

      it 'renders the shared choose_id_type template' do
        get :show

        expect(response).to render_template 'idv/shared/choose_id_type'
      end

      it 'sends analytics_visited event' do
        get :show

        expect(@analytics).to have_logged_event(analytics_name, analytics_args)
      end
    end
  end

  describe '#update' do
    let(:chosen_id_type) { 'drivers_license' }
    let(:analytics_name) { :idv_doc_auth_choose_id_type_submitted }
    let(:idv_vendor) { Idp::Constants::Vendors::LEXIS_NEXIS }
    let(:analytics_args) do
      {
        success: true,
        step: 'hybrid_choose_id_type',
        analytics_id: 'Doc Auth',
        flow_path: 'hybrid',
        chosen_id_type: chosen_id_type,
      }
    end

    let(:params) do
      { doc_auth: { choose_id_type_preference: chosen_id_type } }
    end
    it 'sends analytics submitted event for id choice' do
      put :update, params: params

      expect(@analytics).to have_logged_event(analytics_name, analytics_args)
    end

    context 'user chooses drivers_license' do
      it 'maintains passport_status as allowed and redirects to correct vendor' do
        put :update, params: params
        expect(document_capture_session.passport_status).to eq('not_requested')
        expect(response).to redirect_to idv_hybrid_mobile_document_capture_url
      end
    end

    context 'user chooses passport' do
      let(:chosen_id_type) { 'passport' }
      let(:params) do
        { doc_auth: { choose_id_type_preference: chosen_id_type } }
      end

      it 'sets passport_status to requested and redirects to vendor that supports passport' do
        put :update, params: params
        expect(document_capture_session.passport_status).to eq('requested')
        expect(response).to redirect_to idv_hybrid_mobile_document_capture_url
      end
    end

    context 'when hybrid flow threatmetrix is enabled' do
      let(:tmx_session_id) { 'test-tmx-session-id-1234' }
      let(:request_ip) { Faker::Internet.ip_v4_address }
      let(:proofing_device_hybrid_profiling) { :enabled }

      before do
        controller.session[:hybrid_flow_threatmetrix_session_id] = tmx_session_id
        request.env['REMOTE_ADDR'] = request_ip
      end

      it 'updates DocumentCaptureSession with threatmetrix variables' do
        put :update, params: params

        document_capture_session.reload
        expect(document_capture_session.hybrid_mobile_threatmetrix_session_id).to eq(tmx_session_id)
        expect(document_capture_session.hybrid_mobile_request_ip).to eq(request_ip)
      end

      context 'when user is not in the hybrid mobile tmx ab test bucket' do
        let(:hybrid_mobile_tmx_processed_percent) { 0 }

        it 'does not update DocumentCaptureSession with threatmetrix variables' do
          put :update, params: params

          document_capture_session.reload
          expect(document_capture_session.hybrid_mobile_threatmetrix_session_id).to be_nil
          expect(document_capture_session.hybrid_mobile_request_ip).to be_nil
        end
      end
    end

    context 'when hybrid flow threatmetrix is not enabled' do
      it 'does not update DocumentCaptureSession with threatmetrix variables' do
        put :update, params: params

        document_capture_session.reload
        expect(document_capture_session.hybrid_mobile_threatmetrix_session_id).to be_nil
        expect(document_capture_session.hybrid_mobile_request_ip).to be_nil
      end
    end
  end
end
