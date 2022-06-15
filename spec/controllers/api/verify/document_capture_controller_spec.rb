require 'rails_helper'

describe Api::Verify::DocumentCaptureController do
  include PersonalKeyValidator
  include SamlAuthHelper

  let(:encryption_key) { 'encryption-key' }
  let(:front_image_url) { 'http://example.com/front' }
  let(:front_image_iv) { 'front-iv' }
  let(:back_image_url) { 'http://example.com/back' }
  let(:back_image_iv) { 'back-iv' }
  let(:selfie_image_url) { 'http://example.com/selfie' }
  let(:selfie_image_iv) { 'selfie-iv' }
  let!(:document_capture_session) { DocumentCaptureSession.create!(user: create(:user)) }
  let(:document_capture_session_uuid) { document_capture_session.uuid }
  let(:password) { 'iambatman' }
  let(:user) { create(:user, :signed_up) }
  let(:flow_path) { 'standard' }
  let(:liveness_checking_enabled) { false }
  let(:analytics_data) {
    { browser_attributes: {
      browser_bot: false,
      browser_device_name: "Unknown",
      browser_mobile: false,
      browser_name: "Unknown Browser",
      browser_platform_name: "Unknown",
      browser_platform_version: "0",
      browser_version: "0.0",
      user_agent: "Rails Testing"
    } }
  }

  before do
    allow(IdentityConfig.store).to receive(:idv_api_enabled_steps).and_return(['document_capture'])
    stub_sign_in(user)
  end

  describe '#create' do
    context 'When user document is submitted to be verified ' do
      it 'returns inprogress status when create is called' do
        agent = instance_double(Idv::Agent)
        allow(Idv::Agent).to receive(:new).and_return(agent)

        expect(agent).to receive(:proof_document).with(
          document_capture_session,
          liveness_checking_enabled: liveness_checking_enabled,
          trace_id: nil,
          image_metadata: {},
          analytics_data: analytics_data,
          flow_path: flow_path
        )

        post :create, params: {
          encryption_key: encryption_key,
          front_image_iv: front_image_iv,
          back_image_iv: back_image_iv,
          selfie_image_iv: selfie_image_iv,
          front_image_url: front_image_url,
          back_image_url: back_image_url,
          selfie_image_url: selfie_image_url,
          document_capture_session_uuid: document_capture_session_uuid,
          flow_path: flow_path,
        }
        expect(JSON.parse(response.body)['status']).to eq('in_progress')
        expect(response.status).to eq 200
      end

      context 'When the request does not have all the parameters'
      it 'returns 400 and gives error message' do
        agent = instance_double(Idv::Agent)
        allow(Idv::Agent).to receive(:new).and_return(agent)
        expect(agent).to_not receive(:proof_document)

        post :create, params: {
          encryption_key: encryption_key,
          front_image_iv: nil,
          back_image_iv: back_image_iv,
          selfie_image_iv: selfie_image_iv,
          front_image_url: front_image_url,
          back_image_url: back_image_url,
          selfie_image_url: selfie_image_url,
          document_capture_session_uuid: document_capture_session_uuid,
        }

        expect(JSON.parse(response.body)['errors'].keys.first).to eq('front_image_iv')
        expect(JSON.parse(response.body)['errors']['front_image_iv'][0]).
          to eq('Please fill in this field.')
        expect(response.status).to eq 400
      end
    end
  end
end
