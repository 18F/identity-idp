require 'rails_helper'

RSpec.describe 'idv/shared/_document_capture.html.erb' do
  include Devise::Test::ControllerHelpers

  let(:document_capture_session_uuid) { nil }
  let(:sp_name) { nil }
  let(:sp_issuer) { nil }
  let(:flow_path) { 'standard' }
  let(:failure_to_proof_url) { return_to_sp_failure_to_proof_path }
  let(:in_person_proofing_enabled) { false }
  let(:in_person_proofing_enabled_issuer) { nil }
  let(:acuant_sdk_upgrade_a_b_testing_enabled) { false }
  let(:use_alternate_sdk) { false }
  let(:selfie_capture_enabled) { true }

  let(:acuant_version) { '1.3.3.7' }
  let(:skip_doc_auth_from_how_to_verify) { false }
  let(:skip_doc_auth_from_handoff) { false }
  let(:skip_doc_auth_from_socure) { false }
  let(:socure_errors_timeout_url) { idv_socure_document_capture_errors_url(error_code: :timeout) }
  let(:opted_in_to_in_person_proofing) { false }
  let(:presenter) { Idv::InPerson::UspsFormPresenter.new }
  let(:mock_client) { false }

  before do
    decorated_sp_session = instance_double(
      ServiceProviderSession,
      sp_name: sp_name,
      sp_issuer: sp_issuer,
    )
    allow(view).to receive(:decorated_sp_session).and_return(decorated_sp_session)
    allow(view).to receive(:url_for).and_return('https://example.com/')

    allow(Idv::InPersonConfig).to receive(:enabled_for_issuer?) do |issuer|
      if issuer.nil?
        in_person_proofing_enabled
      else
        issuer == in_person_proofing_enabled_issuer
      end
    end

    assign(:presenter, presenter)
  end

  subject(:render_partial) do
    render partial: 'idv/shared/document_capture', locals: {
      document_capture_session_uuid: document_capture_session_uuid,
      sp_name: sp_name,
      flow_path: flow_path,
      failure_to_proof_url: failure_to_proof_url,
      acuant_sdk_upgrade_a_b_testing_enabled: acuant_sdk_upgrade_a_b_testing_enabled,
      use_alternate_sdk: use_alternate_sdk,
      acuant_version: acuant_version,
      doc_auth_selfie_capture: selfie_capture_enabled,
      skip_doc_auth_from_how_to_verify: skip_doc_auth_from_how_to_verify,
      skip_doc_auth_from_handoff: skip_doc_auth_from_handoff,
      skip_doc_auth_from_socure: skip_doc_auth_from_socure,
      socure_errors_timeout_url: socure_errors_timeout_url,
      opted_in_to_in_person_proofing: opted_in_to_in_person_proofing,
      mock_client: mock_client,
    }
  end

  describe 'in person url' do
    context 'when in person proofing is disabled' do
      let(:in_person_proofing_enabled) { false }

      it 'initializes without in person url' do
        render_partial

        expect(rendered).to_not have_css('#document-capture-form[data-idv-in-person-url]')
      end
    end

    context 'when in person proofing is enabled' do
      let(:in_person_proofing_enabled) { true }

      it 'initializes with in person url' do
        render_partial

        expect(rendered).to have_css(
          "#document-capture-form[data-idv-in-person-url='#{idv_in_person_url}']",
        )
      end

      context 'with an associated service provider' do
        let(:sp_name) { 'Example SP' }
        let(:sp_issuer) { 'example-issuer' }

        it 'initializes without in person url' do
          render_partial

          expect(rendered).to_not have_css('#document-capture-form[data-idv-in-person-url]')
        end

        context 'when in person proofing is enabled for issuer' do
          let(:in_person_proofing_enabled_issuer) { sp_issuer }

          it 'initializes with in person url' do
            render_partial

            expect(rendered).to have_css(
              "#document-capture-form[data-idv-in-person-url='#{idv_in_person_url}']",
            )
          end
        end
      end
    end
  end
  describe 'view variables sent correctly' do
    it 'sends selfie_capture_enabled to the frontend' do
      render_partial
      expect(rendered).to have_css(
        "#document-capture-form[data-doc-auth-selfie-capture='true']",
      )
    end

    it 'sends skip_doc_auth_from_how_to_verify to in the frontend' do
      render_partial
      expect(rendered).to have_css(
        "#document-capture-form[data-skip-doc-auth-from-how-to-verify='false']",
      )
    end

    it 'sends skip_doc_auth_from_handoff to in the frontend' do
      render_partial
      expect(rendered).to have_css(
        "#document-capture-form[data-skip-doc-auth-from-handoff='false']",
      )
    end

    it 'sends skip_doc_auth_from_socure to in the frontend' do
      render_partial
      expect(rendered).to have_css(
        "#document-capture-form[data-skip-doc-auth-from-socure='false']",
      )
    end

    context 'when doc_auth_selfie_capture is false' do
      let(:selfie_capture_enabled) { false }
      it 'does not send doc_auth_selfie_capture to the FE' do
        render_partial
        expect(rendered).to have_css(
          "#document-capture-form[data-doc-auth-selfie-capture='false']",
        )
      end
    end

    context 'when not using doc auth mock client' do
      it 'contains mock-client-data in metadata' do
        render_partial
        expect(rendered).not_to have_css(
          '#document-capture-form[data-mock-client]',
        )
      end
    end

    context 'when using doc auth mock client' do
      let(:mock_client) { true }
      it 'contains mock-client-data in metadata' do
        render_partial
        expect(rendered).to have_css(
          '#document-capture-form[data-mock-client]',
        )
      end
    end
  end
end
