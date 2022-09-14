require 'rails_helper'

describe 'idv/shared/_document_capture.html.erb' do
  include Devise::Test::ControllerHelpers

  let(:async_uploads_enabled) { false }
  let(:flow_session) { {} }
  let(:sp_name) { nil }
  let(:sp_issuer) { nil }
  let(:flow_path) { 'standard' }
  let(:failure_to_proof_url) { return_to_sp_failure_to_proof_path }
  let(:in_person_proofing_enabled) { false }
  let(:in_person_proofing_enabled_issuer) { nil }
  let(:front_image_upload_url) { nil }
  let(:back_image_upload_url) { nil }
  let(:selfie_image_upload_url) { nil }

  before do
    decorated_session = instance_double(
      ServiceProviderSessionDecorator,
      sp_name: sp_name,
      sp_issuer: sp_issuer,
    )
    allow(view).to receive(:decorated_session).and_return(decorated_session)
    allow(view).to receive(:url_for).and_return('https://example.com/')

    allow(FeatureManagement).to receive(:document_capture_async_uploads_enabled?).
      and_return(async_uploads_enabled)
    allow(Idv::InPersonConfig).to receive(:enabled_for_issuer?) do |issuer|
      if issuer.nil?
        in_person_proofing_enabled
      else
        issuer == in_person_proofing_enabled_issuer
      end
    end

    assign(:step_url, :idv_doc_auth_step_url)
  end

  subject(:render_partial) do
    render partial: 'idv/shared/document_capture', locals: {
      flow_session: flow_session,
      sp_name: sp_name,
      flow_path: flow_path,
      failure_to_proof_url: failure_to_proof_url,
      front_image_upload_url: front_image_upload_url,
      back_image_upload_url: back_image_upload_url,
      selfie_image_upload_url: selfie_image_upload_url,
    }
  end

  describe 'async upload urls' do
    context 'when async upload is disabled' do
      let(:async_uploads_enabled) { false }

      it 'does not modify CSP connect_src headers' do
        render_partial

        connect_src = controller.request.content_security_policy.connect_src
        expect(connect_src).to eq(
          ["'self'", '*.nr-data.net'],
        )
      end
    end

    context 'when async upload are enabled' do
      let(:async_uploads_enabled) { true }
      let(:front_image_upload_url) { 'https://s3.example.com/bucket/a?X-Amz-Security-Token=UAOL2' }
      let(:back_image_upload_url) { 'https://s3.example.com/bucket/b?X-Amz-Security-Token=UAOL2' }
      let(:selfie_image_upload_url) { 'https://s3.example.com/bucket/c?X-Amz-Security-Token=UAOL2' }

      it 'does modifies CSP connect_src headers to include upload urls' do
        render_partial

        connect_src = controller.request.content_security_policy.connect_src
        expect(connect_src).to include('https://s3.example.com/bucket/a')
        expect(connect_src).to include('https://s3.example.com/bucket/b')
        expect(connect_src).to include('https://s3.example.com/bucket/c')
      end
    end
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
