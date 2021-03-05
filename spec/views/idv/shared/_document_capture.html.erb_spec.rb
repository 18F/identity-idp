require 'rails_helper'

describe 'idv/shared/_document_capture.html.erb' do
  include Devise::Test::ControllerHelpers

  let(:flow_session) { {} }
  let(:sp_name) { nil }
  let(:failure_to_proof_url) { return_to_sp_failure_to_proof_path }
  let(:front_image_upload_url) { nil }
  let(:back_image_upload_url) { nil }
  let(:selfie_image_upload_url) { nil }

  before do
    allow(view).to receive(:url_for).and_return('https://example.com/')

    allow(FeatureManagement).to receive(:document_capture_async_uploads_enabled?).
      and_return(async_uploads_enabled)

    assign(:step_url, :idv_doc_auth_step_url)
  end

  subject(:render_partial) do
    render partial: 'idv/shared/document_capture', locals: {
      flow_session: flow_session,
      sp_name: sp_name,
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
        allow(SecureHeaders).to receive(:append_content_security_policy_directives).with(any_args)
        expect(SecureHeaders).to receive(:append_content_security_policy_directives).with(
          controller.request,
          connect_src: [],
        )

        render_partial
      end
    end

    context 'when async upload are enabled' do
      let(:async_uploads_enabled) { true }
      let(:front_image_upload_url) { 'https://s3.example.com/bucket/a?X-Amz-Security-Token=UAOL2' }
      let(:back_image_upload_url) { 'https://s3.example.com/bucket/b?X-Amz-Security-Token=UAOL2' }
      let(:selfie_image_upload_url) { 'https://s3.example.com/bucket/c?X-Amz-Security-Token=UAOL2' }

      it 'does modifies CSP connect_src headers to include upload urls' do
        allow(SecureHeaders).to receive(:append_content_security_policy_directives).with(any_args)
        expect(SecureHeaders).to receive(:append_content_security_policy_directives).with(
          controller.request,
          connect_src: [
            'https://s3.example.com/bucket/a',
            'https://s3.example.com/bucket/b',
            'https://s3.example.com/bucket/c',
          ],
        )

        render_partial
      end
    end
  end
end
