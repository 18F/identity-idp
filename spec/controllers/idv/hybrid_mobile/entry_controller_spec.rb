require 'rails_helper'

RSpec.describe Idv::HybridMobile::EntryController do
  describe '#show' do
    let(:user) { create(:user) }
    let(:passport_status) { nil }

    let!(:document_capture_session) do
      create(
        :document_capture_session,
        user:,
        requested_at: Time.zone.now,
        passport_status:,
      )
    end

    let(:session_uuid) { document_capture_session.uuid }

    around do |ex|
      REDIS_POOL.with { |client| client.flushdb }
      ex.run
      REDIS_POOL.with { |client| client.flushdb }
    end

    context 'with no session' do
      before do
        get :show
      end

      it 'redirects to the root url' do
        expect(response).to redirect_to root_url
      end
    end

    context 'with a bad session' do
      before do
        get :show, params: { 'document-capture-session': 'foo' }
      end

      it 'redirects to the root url' do
        expect(response).to redirect_to root_url
      end
    end

    context 'with an expired token' do
      before do
        travel_to(Time.zone.now + 1.day) do
          get :show, params: { 'document-capture-session': session_uuid }
        end
      end

      it 'redirects to the root url' do
        expect(response).to redirect_to root_url
      end
    end

    context 'with a good session uuid' do
      let(:session) do
        {}
      end
      let(:idv_vendor) { Idp::Constants::Vendors::MOCK }
      let(:vendor_switching_enabled) { true }
      let(:lexis_nexis_percent) { 100 }
      let(:socure_user_limit) { 10 }
      let(:acr_values) do
        [
          Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF,
          Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF,
        ].join(' ')
      end

      before do
        allow(controller).to receive(:session).and_return(session)
        get :show, params: { 'document-capture-session': session_uuid }
      end

      it 'redirects to the first step' do
        expect(document_capture_session.doc_auth_vendor).to be_nil
        expect(response).to redirect_to idv_hybrid_mobile_choose_id_type_url
      end


      context 'doc auth vendor is mock' do
        let(:idv_vendor) { Idp::Constants::Vendors::MOCK }
        before do
          document_capture_session.update(doc_auth_vendor: idv_vendor)
        end

        it 'redirects to the first step' do
          expect(response).to redirect_to idv_hybrid_mobile_choose_id_type_url
        end
      end

      context 'passport allowed' do
        before do
          allow(IdentityConfig.store).to receive(:doc_auth_passport_enabled).and_return(false)
        end

        it 'redirects to choose id type step' do
          expect(response).to redirect_to idv_hybrid_mobile_choose_id_type_url
        end
      end
    end
  end
end
