require 'rails_helper'

describe 'idv/shared/_document_capture.html.erb' do
  include Devise::Test::ControllerHelpers

  let(:flow_session) { {} }
  let(:sp_name) { nil }
  let(:failure_to_proof_url) { 'https://example.com' }
  let(:front_image_upload_url) { nil }
  let(:back_image_upload_url) { nil }
  let(:selfie_image_upload_url) { nil }

  before do
    allow(view).to receive(:flow_session).and_return(flow_session)
    allow(view).to receive(:sp_name).and_return(sp_name)
    allow(view).to receive(:failure_to_proof_url).and_return(failure_to_proof_url)
    allow(view).to receive(:front_image_upload_url).and_return(front_image_upload_url)
    allow(view).to receive(:back_image_upload_url).and_return(back_image_upload_url)
    allow(view).to receive(:selfie_image_upload_url).and_return(selfie_image_upload_url)
    allow(view).to receive(:url_for).and_return('https://example.com/')
  end

  describe 'async upload urls' do
    context 'when async upload is disabled' do
      it 'does not modify CSP connect_src headers' do
        allow(SecureHeaders).to receive(:append_content_security_policy_directives).with(any_args)
        expect(SecureHeaders).to receive(:append_content_security_policy_directives).with(
          controller.request,
          connect_src: [],
        )

        render
      end
    end

    context 'when async upload is enabled' do
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

        render
      end
    end
  end
end
