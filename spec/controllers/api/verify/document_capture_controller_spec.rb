require 'rails_helper'

describe Api::Verify::DocumentCaptureController do
  include PersonalKeyValidator
  include SamlAuthHelper

  let(:encryption_key) { 'encryption-key' }
  let(:front_image_url) { 'http://example.com/front' }
  let(:front_image_iv) { 'front-iv' }
  let(:back_image_url) { 'http://example.com/back' }
  let(:back_image_iv) { 'back-iv' }
  let(:front_image_metadata) do
    { width: 40, height: 40, mimeType: 'image/png', source: 'upload' }
  end
  let(:back_image_metadata) do
    { width: 20, height: 20, mimeType: 'image/png', source: 'upload' }
  end
  let(:image_metadata) { { front: front_image_metadata, back: back_image_metadata } }
  let!(:document_capture_session) { DocumentCaptureSession.create!(user: create(:user)) }
  let(:document_capture_session_uuid) { document_capture_session.uuid }
  let(:password) { 'iambatman' }
  let(:user) { create(:user, :signed_up) }
  let(:flow_path) { 'standard' }
  let(:analytics_data) do
    { browser_attributes:
      { browser_bot: false,
        browser_device_name: 'Unknown',
        browser_mobile: false,
        browser_name: 'Unknown Browser',
        browser_platform_name: 'Unknown',
        browser_platform_version: '0',
        browser_version: '0.0',
        user_agent: 'Rails Testing' } }
  end

  before do
    stub_sign_in(user) if user
  end

  it 'extends behavior of base api class' do
    expect(subject).to be_kind_of Api::Verify::BaseController
  end

  describe '#create' do
    it 'renders as bad request (400)' do
      post :create

      expect(response.status).to eq(400)
    end

    context 'signed out' do
      let(:user) { nil }

      it 'renders as unauthorized (401)' do
        post :create

        expect(response.status).to eq(401)
      end

      context 'with hybrid effective user' do
        before { session[:doc_capture_user_id] = create(:user).id }

        it 'renders as bad request (400)' do
          post :create

          expect(response.status).to eq(400)
        end
      end
    end

    context 'When user document is submitted to be verified' do
      it 'returns inprogress status when create is called' do
        agent = instance_double(Idv::Agent)
        allow(Idv::Agent).to receive(:new).with(
          {
            user_uuid: user.uuid,
            uuid_prefix: nil,
            document_arguments: {
              'encryption_key' => encryption_key,
              'front_image_iv' => front_image_iv,
              'back_image_iv' => back_image_iv,
              'front_image_url' => front_image_url,
              'back_image_url' => back_image_url,
            },
          },
        ).and_return(agent)

        expect(agent).to receive(:proof_document).with(
          document_capture_session,
          trace_id: nil,
          image_metadata: image_metadata,
          analytics_data: analytics_data,
          flow_path: flow_path,
        )

        post :create, params: {
          encryption_key: encryption_key,
          front_image_iv: front_image_iv,
          back_image_iv: back_image_iv,
          front_image_url: front_image_url,
          back_image_url: back_image_url,
          front_image_metadata: front_image_metadata.to_json,
          back_image_metadata: back_image_metadata.to_json,
          document_capture_session_uuid: document_capture_session_uuid,
          flow_path: flow_path,
        }
        expect(JSON.parse(response.body, symbolize_names: true)).to eq(
          success: true,
          status: 'in_progress',
        )
        expect(response.status).to eq 202
      end

      context 'When the request does not have all the parameters' do
        it 'returns 400 and gives error message' do
          agent = instance_double(Idv::Agent)
          allow(Idv::Agent).to receive(:new).and_return(agent)
          expect(agent).to_not receive(:proof_document)

          post :create, params: {
            encryption_key: encryption_key,
            front_image_iv: nil,
            back_image_iv: back_image_iv,
            front_image_url: front_image_url,
            back_image_url: back_image_url,
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
end
