require 'rails_helper'

RSpec.describe Idv::HybridMobile::EntryController do
  describe '#show' do
    let(:user) { create(:user) }

    let!(:document_capture_session) do
      DocumentCaptureSession.create!(
        user: user,
        requested_at: Time.zone.now,
      )
    end

    let(:session_uuid) { document_capture_session.uuid }
    let(:idv_vendor) { Idp::Constants::Vendors::MOCK }

    around do |ex|
      REDIS_POOL.with { |client| client.flushdb }
      ex.run
      REDIS_POOL.with { |client| client.flushdb }
    end

    before do
      allow(IdentityConfig.store).to receive(:doc_auth_vendor).and_return(idv_vendor)
      allow(IdentityConfig.store).to receive(:doc_auth_vendor_default).and_return(idv_vendor)
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
        resolved_authn_context = AuthnContextResolver.new(
          user: user,
          service_provider: nil,
          vtr: nil,
          acr_values: acr_values,
        ).result
        allow(controller).to receive(:session).and_return(session)
        allow(controller).to receive(:resolved_authn_context_result)
          .and_return(resolved_authn_context)
        allow(IdentityConfig.store).to receive(:doc_auth_vendor_switching_enabled)
          .and_return(vendor_switching_enabled)
        allow(IdentityConfig.store).to receive(:doc_auth_vendor_lexis_nexis_percent)
          .and_return(lexis_nexis_percent)
        allow(IdentityConfig.store).to receive(:doc_auth_socure_max_allowed_users)
          .and_return(socure_user_limit)
        get :show, params: { 'document-capture-session': session_uuid }
      end

      context 'doc auth vendor is socure' do
        let(:idv_vendor) { Idp::Constants::Vendors::SOCURE }

        it 'redirects to the first step' do
          expect(response).to redirect_to idv_hybrid_mobile_socure_document_capture_url
        end
      end

      context 'doc auth vendor is socure with socure user limit reached' do
        let(:idv_vendor) { Idp::Constants::Vendors::SOCURE }
        let(:socure_user_limit) { 0 }

        it 'redirects to the lexis nexis first step' do
          expect(response).to redirect_to idv_hybrid_mobile_document_capture_url
        end
      end

      context 'facial match is required' do
        let(:acr_values) do
          [
            Saml::Idp::Constants::IAL2_BIO_REQUIRED_AUTHN_CONTEXT_CLASSREF,
            Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF,
          ].join(' ')
        end

        context 'doc auth vendor is socure with facial match required' do
          let(:idv_vendor) { Idp::Constants::Vendors::SOCURE }

          it 'redirects to the lexis nexis first step' do
            expect(response).to redirect_to idv_hybrid_mobile_document_capture_url
          end
        end

        context 'doc auth vendor is mock with facial match required' do
          let(:idv_vendor) { Idp::Constants::Vendors::MOCK }

          it 'redirects to the lexis nexis first step' do
            expect(response).to redirect_to idv_hybrid_mobile_document_capture_url
          end
        end

        context 'lexis nexis is disabled' do
          let(:idv_vendor) { nil }
          let(:vendor_switching_enabled) { false }
          let(:lexis_nexis_percent) { 0 }

          before do
            allow(IdentityConfig.store).to receive(:doc_auth_vendor_lexis_nexis_percent)
              .and_return(lexis_nexis_percent)
          end

          it 'causes an 404 error' do
            expect(response.status).to eq(404)
          end
        end
      end

      context 'doc auth vendor is lexis nexis' do
        let(:idv_vendor) { Idp::Constants::Vendors::LEXIS_NEXIS }

        it 'redirects to the first step' do
          expect(response).to redirect_to idv_hybrid_mobile_document_capture_url
        end
      end

      context 'doc auth vendor is mock' do
        let(:idv_vendor) { Idp::Constants::Vendors::MOCK }

        it 'redirects to the first step' do
          expect(response).to redirect_to idv_hybrid_mobile_document_capture_url
        end
      end

      context 'AB vendor percentages are 0' do
        context 'when default bucket it mock' do
          let(:lexis_nexis_percent) { 0 }
          let(:idv_vendor) { Idp::Constants::Vendors::MOCK }

          before do
            allow(IdentityConfig.store).to receive(:doc_auth_vendor_socure_percent)
              .and_return(0)
          end

          it 'redirects to the default vendor' do
            expect(response).to redirect_to idv_hybrid_mobile_document_capture_url
          end
        end

        context 'when default bucket it socure' do
          let(:lexis_nexis_percent) { 0 }
          let(:idv_vendor) { Idp::Constants::Vendors::SOCURE }

          before do
            allow(IdentityConfig.store).to receive(:doc_auth_vendor_socure_percent)
              .and_return(0)
          end

          it 'redirects to the default vendor' do
            expect(response).to redirect_to idv_hybrid_mobile_socure_document_capture_url
          end
        end
      end

      context 'but we already had a session' do
        let!(:different_document_capture_session) do
          DocumentCaptureSession.create!(
            user: user,
            requested_at: Time.zone.now,
          )
        end

        let(:session) do
          {
            doc_capture_user_id: user.id,
            document_capture_session_uuid: different_document_capture_session.uuid,
          }
        end

        it 'assumes new document capture session' do
          expect(controller.session).to include(document_capture_session_uuid: session_uuid)
        end

        context 'doc auth vendor is socure' do
          let(:idv_vendor) { Idp::Constants::Vendors::SOCURE }

          it 'redirects to the socure document capture screen' do
            expect(response).to redirect_to idv_hybrid_mobile_socure_document_capture_url
          end
        end

        context 'doc auth vendor is lexis nexis' do
          let(:idv_vendor) { Idp::Constants::Vendors::LEXIS_NEXIS }

          it 'redirects to the document capture screen' do
            expect(response).to redirect_to idv_hybrid_mobile_document_capture_url
          end
        end
      end
    end

    context 'with a user id in session and no session uuid' do
      let(:user) { create(:user) }

      before do
        session[:doc_capture_user_id] = user.id
        get :show
      end

      context 'doc auth vendor is socure' do
        let(:idv_vendor) { Idp::Constants::Vendors::SOCURE }

        it 'redirects to the first step' do
          expect(response).to redirect_to idv_hybrid_mobile_socure_document_capture_url
        end
      end

      context 'doc auth vendor is lexis nexis' do
        it 'redirects to the first step' do
          expect(response).to redirect_to idv_hybrid_mobile_document_capture_url
        end
      end
    end
  end
end
