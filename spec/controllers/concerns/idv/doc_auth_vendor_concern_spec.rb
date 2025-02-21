require 'rails_helper'

RSpec.describe Idv::DocAuthVendorConcern, :controller do
  let(:user) { create(:user) }
  let(:socure_user_set) { Idv::SocureUserSet.new }
  let(:bucket) { :mock }

  controller ApplicationController do
    include Idv::DocAuthVendorConcern
  end

  around do |ex|
    REDIS_POOL.with { |client| client.flushdb }
    ex.run
    REDIS_POOL.with { |client| client.flushdb }
  end

  describe '#doc_auth_vendor' do
    before do
      allow(controller).to receive(:current_user).and_return(user)
      allow(controller).to receive(:ab_test_bucket)
        .with(:DOC_AUTH_VENDOR)
        .and_return(bucket)
      allow(controller).to receive(:document_capture_session)
        .and_return(create(:document_capture_session, user:))
    end

    context 'bucket is LexisNexis' do
      let(:bucket) { :lexis_nexis }

      it 'returns lexis nexis as the vendor' do
        expect(controller.doc_auth_vendor).to eq(Idp::Constants::Vendors::LEXIS_NEXIS)
        expect(controller.document_capture_session.doc_auth_vendor)
          .to eq(Idp::Constants::Vendors::LEXIS_NEXIS)
      end
    end

    context 'bucket is Mock' do
      let(:bucket) { :mock }

      it 'returns mock as the vendor' do
        expect(controller.doc_auth_vendor).to eq(Idp::Constants::Vendors::MOCK)
        expect(controller.document_capture_session.doc_auth_vendor)
          .to eq(Idp::Constants::Vendors::MOCK)
      end
    end

    context 'bucket is Socure' do
      let(:bucket) { :socure }

      context 'current user is undefined so use document_capture_session user' do
        before do
          allow(controller).to receive(:current_user).and_return(nil)
          allow(controller).to receive(:document_capture_user).and_return(user)
        end

        it 'returns socure as the vendor' do
          expect(controller.doc_auth_vendor).to eq(Idp::Constants::Vendors::SOCURE)
          expect(controller.document_capture_session.doc_auth_vendor)
            .to eq(Idp::Constants::Vendors::SOCURE)
        end

        it 'adds a user to the socure redis set' do
          expect { controller.doc_auth_vendor }.to change { socure_user_set.count }.by(1)
        end
      end

      context 'current user is defined' do
        it 'returns socure as the vendor' do
          expect(controller.doc_auth_vendor).to eq(Idp::Constants::Vendors::SOCURE)
        end

        it 'adds a user to the socure redis set' do
          expect { controller.doc_auth_vendor }.to change { socure_user_set.count }.by(1)
        end
      end
    end

    context 'facial match is required' do
      let(:bucket) { :socure }
      let(:acr_values) do
        [
          Saml::Idp::Constants::IAL2_BIO_REQUIRED_AUTHN_CONTEXT_CLASSREF,
          Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF,
        ].join(' ')
      end

      before do
        allow(IdentityConfig.store)
          .to receive(:doc_auth_vendor_switching_enabled).and_return(true)
        allow(IdentityConfig.store)
          .to receive(:doc_auth_vendor_lexis_nexis_percent).and_return(50)
        allow(controller).to receive(:resolved_authn_context_result).and_return(true)
        resolved_authn_context = AuthnContextResolver.new(
          user: user,
          service_provider: nil,
          vtr: nil,
          acr_values: acr_values,
        ).result
        allow(controller).to receive(:resolved_authn_context_result)
          .and_return(resolved_authn_context)
      end

      it 'returns Lexis Nexis as the vendor' do
        expect(controller.doc_auth_vendor).to eq(Idp::Constants::Vendors::LEXIS_NEXIS)
      end

      context 'Lexis Nexis is disabled' do
        before do
          allow(IdentityConfig.store)
            .to receive(:doc_auth_vendor_lexis_nexis_percent).and_return(0)
        end

        it 'returns mock vendor' do
          expect(controller.doc_auth_vendor).to eq(Idp::Constants::Vendors::MOCK)
        end
      end

      context 'Lexis Nexis is disabled' do
        before do
          allow(IdentityConfig.store)
            .to receive(:doc_auth_vendor_lexis_nexis_percent).and_return(0)
        end

        it 'returns mock vendor' do
          expect(controller.doc_auth_vendor).to eq(Idp::Constants::Vendors::MOCK)
        end
      end
    end
  end

  describe '#doc_auth_vendor_enabled?' do
    let(:vendor) { Idp::Constants::Vendors::LEXIS_NEXIS }

    context 'doc_auth_vendor_switching is false' do
      before do
        allow(IdentityConfig.store)
          .to receive(:doc_auth_vendor_switching_enabled).and_return(false)
      end

      it 'returns false' do
        expect(controller.doc_auth_vendor_enabled?(vendor)).to eq false
      end
    end

    context 'Lexis Nexis is disabled' do
      before do
        allow(IdentityConfig.store)
          .to receive(:doc_auth_vendor_switching_enabled).and_return(true)
        allow(IdentityConfig.store)
          .to receive(:doc_auth_vendor_lexis_nexis_percent).and_return(0)
      end

      it 'returns false' do
        expect(controller.doc_auth_vendor_enabled?(vendor)).to eq false
      end

      context 'session already assigned LexisNexis doc auth vendor' do
        before do
          allow(controller).to receive(:document_capture_session)
            .and_return(create(:document_capture_session, user:))
          allow(IdentityConfig.store).to receive(:doc_auth_vendor_default)
            .and_return(Idp::Constants::Vendors::MOCK)
          controller.document_capture_session
            .update!(doc_auth_vendor: Idp::Constants::Vendors::LEXIS_NEXIS)
        end
        it 'lexis_nexis is still docauth vendor' do
          expect(DocAuthRouter).not_to receive(:doc_auth_vendor_for_bucket)
          expect(controller.doc_auth_vendor).to eq(Idp::Constants::Vendors::LEXIS_NEXIS)
          expect(controller.document_capture_session.doc_auth_vendor)
            .to eq(Idp::Constants::Vendors::LEXIS_NEXIS)
        end
      end
    end
  end
end
