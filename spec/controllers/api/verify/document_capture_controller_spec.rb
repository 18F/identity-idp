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
  let(:user) { create(:user, :signed_up, password: password) }

  before do
    allow(IdentityConfig.store).to receive(:idv_api_enabled_steps).and_return(['document_capture'])
    stub_sign_in(user)
  end

  describe '#create' do
    context 'When user document is submitted to be verified ' do
      it 'returns inprogress status when create is called' do
        agent = instance_double(Idv::Agent)
        allow(Idv::Agent).to receive(:new).and_return(agent)
        expect(agent).to receive(:proof_document)

        post :create, params: {
          encryption_key: encryption_key,
          front_image_iv: front_image_iv,
          back_image_iv: back_image_iv,
          selfie_image_iv: selfie_image_iv,
          front_image_url: front_image_url,
          back_image_url: back_image_url,
          selfie_image_url: selfie_image_url,
          document_capture_session_uuid: document_capture_session_uuid,
        }
        expect(JSON.parse(response.body)['status']).to eq('in_progress')
        expect(response.status).to eq 200
      end

      it 'returns 400 if not successful' do
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

        expect(JSON.parse(response.body)['error']).to be_truthy
        expect(response.status).to eq 400
      end
    end
  end
end
