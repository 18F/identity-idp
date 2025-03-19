require 'rails_helper'

RSpec.describe Idv::HybridMobile::ChooseIdTypeController do
  let(:idv_vendor) { Idp::Constants::Vendors::MOCK }
  let(:user) { create(:user) }
  let(:passport_status) { 'allowed' }

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

  before do
    stub_analytics
    session[:doc_capture_user_id] = user&.id
    session[:document_capture_session_uuid] = document_capture_session_uuid

    allow(IdentityConfig.store).to receive(:doc_auth_vendor).and_return(idv_vendor)
    allow(IdentityConfig.store).to receive(:doc_auth_vendor_default).and_return(idv_vendor)
    allow(subject).to receive(:document_capture_session).and_return(document_capture_session)
  end

  describe 'before actions' do
    it 'includes correct before_actions' do
      expect(subject).to have_actions(
        :before,
        :redirect_if_passport_not_available,
      )
      expect(subject).to have_actions(
        :before,
        :check_valid_document_capture_session,
      )
    end
  end
  describe '#show' do
    context 'passport not available' do
      let(:passport_status) { nil }
      let(:idv_vendor) { Idp::Constants::Vendors::SOCURE }
      it 'redirects to the vendor document capture' do
        get :show
        expect(response).to redirect_to idv_hybrid_mobile_socure_document_capture_url
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

      it 'renders the show template' do
        get :show

        expect(response).to render_template :show
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
    let(:idv_vendor) { Idp::Constants::Vendors::SOCURE }
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
        expect(document_capture_session.passport_status).to eq('allowed')
        expect(response).to redirect_to idv_hybrid_mobile_socure_document_capture_url
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
  end
end
