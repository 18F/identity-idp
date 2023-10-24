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
  let(:phone_question_ab_test_bucket) { :bypass_phone_question }
  let(:acuant_version) { '1.3.3.7' }

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
      phone_question_ab_test_bucket: phone_question_ab_test_bucket,
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
end
