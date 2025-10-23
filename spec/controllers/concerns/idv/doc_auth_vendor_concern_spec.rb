require 'rails_helper'

RSpec.describe Idv::DocAuthVendorConcern, :controller do
  let(:document_capture_session) { create(:document_capture_session) }
  let(:user) { document_capture_session.user }
  let(:bucket) { :mock }
  let(:user_session) do
    {}
  end
  let(:idv_session) do
    Idv::Session.new(
      user_session:,
      current_user: user,
      service_provider: nil,
    )
  end

  controller ApplicationController do
    include Idv::DocAuthVendorConcern
  end

  before do
    stub_sign_in(user)
    allow(controller).to receive(:current_user).and_return(user)
    allow(controller).to receive(:idv_session).and_return(idv_session)
    allow(controller).to receive(:document_capture_session)
      .and_return(document_capture_session)
  end

  describe '#udpate_doc_auth_vendor' do
    context 'facial match not required' do
      context 'passport has not been requested' do
        before do
          allow(controller).to receive(:ab_test_bucket)
            .with(:DOC_AUTH_VENDOR, user:)
            .and_return(bucket)
        end

        context 'bucket is LexisNexis' do
          let(:bucket) { :lexis_nexis }

          it 'returns lexis nexis as the vendor' do
            controller.update_doc_auth_vendor

            expect(document_capture_session.doc_auth_vendor)
              .to eq(Idp::Constants::Vendors::LEXIS_NEXIS)
          end
        end

        context 'bucket is Mock' do
          let(:bucket) { :mock }

          it 'returns mock as the vendor' do
            controller.update_doc_auth_vendor

            expect(document_capture_session.doc_auth_vendor)
              .to eq(Idp::Constants::Vendors::MOCK)
          end
        end

        context 'bucket is Socure' do
          let(:bucket) { :socure }

          it 'returns socure as the vendor' do
            controller.update_doc_auth_vendor

            expect(document_capture_session.doc_auth_vendor)
              .to eq(Idp::Constants::Vendors::SOCURE)
          end
        end
      end

      context 'passport requested' do
        before do
          document_capture_session.update!(passport_status: 'requested')
          allow(controller).to receive(:ab_test_bucket)
            .with(:DOC_AUTH_PASSPORT_VENDOR, user:)
            .and_return(bucket)
        end

        context 'bucket is Socure' do
          let(:bucket) { :socure }

          it 'returns socure as the vendor' do
            controller.update_doc_auth_vendor

            expect(document_capture_session.doc_auth_vendor)
              .to eq(Idp::Constants::Vendors::SOCURE)
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

      context 'passport has not been requested' do
        before do
          allow(controller).to receive(:ab_test_bucket)
            .with(:DOC_AUTH_SELFIE_VENDOR, user:)
            .and_return(bucket)
        end

        it 'returns Socure as the vendor' do
          controller.update_doc_auth_vendor

          expect(document_capture_session.doc_auth_vendor)
            .to eq(Idp::Constants::Vendors::SOCURE)
        end
      end

      context 'passport requested' do
        before do
          document_capture_session.update!(passport_status: 'requested')
          allow(controller).to receive(:ab_test_bucket)
            .with(:DOC_AUTH_PASSPORT_SELFIE_VENDOR, user:)
            .and_return(bucket)
        end

        it 'returns Socure as the vendor' do
          controller.update_doc_auth_vendor

          expect(document_capture_session.doc_auth_vendor)
            .to eq(Idp::Constants::Vendors::SOCURE)
        end
      end
    end
  end
end
