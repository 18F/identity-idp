require 'rails_helper'

RSpec.describe Idv::DocAuthVendorConcern, :controller do
  let(:user) { create(:user) }
  let(:socure_user_set) { Idv::SocureUserSet.new }
  let(:bucket) { :mock }
<<<<<<< HEAD
  let(:user_session) do
    {}
  end
  let(:idv_session) do
    Idv::Session.new(
      user_session:,
=======
  let(:idv_session) do
    Idv::Session.new(
      user_session: {},
>>>>>>> 7b139c15f0 (remove document capture session from doc auth vendor spec)
      current_user: user,
      service_provider: nil,
    )
  end

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
      allow(controller).to receive(:idv_session).and_return(idv_session)
    end

    context 'bucket is LexisNexis' do
      let(:bucket) { :lexis_nexis }

      it 'returns lexis nexis as the vendor' do
        expect(controller.doc_auth_vendor).to eq(Idp::Constants::Vendors::LEXIS_NEXIS)
        expect(controller.idv_session.bucketed_doc_auth_vendor)
          .to eq(Idp::Constants::Vendors::LEXIS_NEXIS)
      end
    end

    context 'bucket is Mock' do
      let(:bucket) { :mock }

      it 'returns mock as the vendor' do
        expect(controller.doc_auth_vendor).to eq(Idp::Constants::Vendors::MOCK)
        expect(idv_session.bucketed_doc_auth_vendor)
          .to eq(Idp::Constants::Vendors::MOCK)
      end
    end

    context 'bucket is Socure' do
      let(:bucket) { :socure }

      context 'current user is undefined so use document_capture_session user' do
        it 'returns socure as the vendor' do
          expect(controller.doc_auth_vendor).to eq(Idp::Constants::Vendors::SOCURE)
          expect(controller.idv_session.bucketed_doc_auth_vendor)
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

    context 'facial match not required' do
      let(:bucket) { :socure }
      before do
        allow(IdentityConfig.store)
          .to receive(:doc_auth_vendor_switching_enabled).and_return(true)
        allow(IdentityConfig.store)
          .to receive(:doc_auth_vendor_socure_percent).and_return(100)
        allow(IdentityConfig.store)
          .to receive(:doc_auth_vendor_lexis_nexis_percent).and_return(0)
      end

      context 'socure user limit reached' do
        before do
          allow(IdentityConfig.store).to receive(:doc_auth_socure_max_allowed_users).and_return(0)
        end

        it 'returns mock as the vendor' do
          expect(controller.doc_auth_vendor).to eq(Idp::Constants::Vendors::MOCK)
        end
      end

      context 'socure user limit not reached' do
        before do
          allow(IdentityConfig.store).to receive(:doc_auth_socure_max_allowed_users).and_return(1)
          allow(controller).to receive(:user_session).and_return(user_session)
        end

        it 'returns socure as the vendor' do
          expect(controller.doc_auth_vendor).to eq(Idp::Constants::Vendors::SOCURE)
        end

        context 'socure user set is maxed before user added' do
          before do
            allow(controller).to receive(:socure_user_set).and_return(socure_user_set)
            allow(socure_user_set).to receive(:add_user!).and_return(false)
          end

          it 'returns mock as the vendor' do
            expect(controller.doc_auth_vendor).to eq(Idp::Constants::Vendors::MOCK)
          end
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

      context 'socure previously bucketed' do
        before do
          idv_session.bucketed_doc_auth_vendor = Idp::Constants::Vendors::SOCURE
        end

        it 'returns mock vendor' do
          expect(controller.doc_auth_vendor).to eq(Idp::Constants::Vendors::LEXIS_NEXIS)
        end
      end

      context 'lexis nexis previously bucketed' do
        before do
          idv_session.bucketed_doc_auth_vendor = Idp::Constants::Vendors::LEXIS_NEXIS
        end

        it 'returns mock vendor' do
          expect(DocAuthRouter).not_to receive(:doc_auth_vendor_for_bucket)
          expect(controller.doc_auth_vendor).to eq(Idp::Constants::Vendors::LEXIS_NEXIS)
        end
      end
    end
  end

  describe '#doc_auth_vendor_enabled?' do
    let(:vendor) { Idp::Constants::Vendors::LEXIS_NEXIS }

    before do
      allow(controller).to receive(:idv_session).and_return(idv_session)
    end

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
          allow(IdentityConfig.store).to receive(:doc_auth_vendor_default)
            .and_return(Idp::Constants::Vendors::MOCK)
          controller.idv_session.bucketed_doc_auth_vendor = Idp::Constants::Vendors::LEXIS_NEXIS
        end
        it 'lexis_nexis is still docauth vendor' do
          expect(DocAuthRouter).not_to receive(:doc_auth_vendor_for_bucket)
          expect(controller.doc_auth_vendor).to eq(Idp::Constants::Vendors::LEXIS_NEXIS)
        end
      end
    end
  end
end
