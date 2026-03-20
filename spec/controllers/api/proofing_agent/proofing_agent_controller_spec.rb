# frozen_string_literal: true

require 'rails_helper'

RSpec.shared_examples 'an endpoint that requires authorization' do
  context 'with no Authorization header' do
    let(:auth_header) { nil }

    it 'returns a 401' do
      expect(action.status).to eq 401

      expect(@analytics).to have_logged_event(
        :proofing_agent_request,
        success: false,
      )
    end
  end

  context 'when Authorization header is an empty string' do
    let(:auth_header) { '' }

    it 'returns a 401' do
      expect(action.status).to eq 401

      expect(@analytics).to have_logged_event(
        :proofing_agent_request,
        success: false,
      )
    end
  end

  context 'without a Bearer token Authorization header' do
    let(:auth_header) { "#{issuer} #{token}" }

    it 'returns a 401' do
      expect(action.status).to eq 401
      expect(@analytics).to have_logged_event(
        :proofing_agent_request,
        success: false,
      )
    end
  end

  context 'without a valid issuer' do
    context 'an unknown issuer' do
      let(:issuer) { 'random-issuer' }

      it 'returns a 401' do
        expect(action.status).to eq 401
        expect(@analytics).to have_logged_event(
          :proofing_agent_request,
          issuer: issuer,
          success: false,
        )
      end
    end
  end

  context 'without a valid token' do
    let(:auth_header) { "Bearer #{issuer}" }

    it 'returns a 401' do
      expect(action.status).to eq 401
      expect(@analytics).to have_logged_event(
        :proofing_agent_request,
        success: false,
      )
    end
  end

  context 'with a different token than they were issued' do
    let(:auth_header) { "Bearer #{issuer} not-shared-secret" }

    it 'returns a 401' do
      expect(action.status).to eq 401
      expect(@analytics).to have_logged_event(
        :proofing_agent_request,
        issuer: issuer,
        success: false,
      )
    end
  end
end

RSpec.describe Api::ProofingAgent::ProofingAgentController do
  include Rails.application.routes.url_helpers
  let(:enabled) { false }
  let(:sp) { create(:service_provider) }
  let(:issuer) { sp.issuer }

  let(:token) { 'a-shared-secret' }
  let(:salt) { SecureRandom.hex(32) }
  let(:cost) { IdentityConfig.store.scrypt_cost }

  let(:hashed_token) do
    scrypt_salt = cost + OpenSSL::Digest::SHA256.hexdigest(salt)
    scrypted = SCrypt::Engine.hash_secret token, scrypt_salt, 32
    SCrypt::Password.new(scrypted).digest
  end

  let(:auth_header) { "Bearer #{issuer} #{token}" }
  let(:request_id) { 'test-request-id' }
  before do
    stub_analytics
    request.headers['Authorization'] = auth_header
    request.headers['X-Request-ID'] = request_id
    allow(IdentityConfig.store).to receive(:idv_proofing_agent_config).and_return(
      [{
        'issuer' => sp.issuer,
        'tokens' => [{ 'value' => hashed_token, 'salt' => salt, 'cost' => cost }],
      }],
    )
    allow(FeatureManagement).to receive(:idv_proofing_agent_enabled?).and_return(enabled)
  end

  describe '#search_user' do
    let(:action) { post :search_user }

    context 'when proofing agent is not enabled' do
      it 'returns 404' do
        expect(action.status).to eq(404)
      end
    end

    context 'when proofing agent is enabled' do
      let(:enabled) { true }

      context 'with a valid authorization header' do
        it 'returns 200' do
          expect(action.status).to eq(200)
          expect(@analytics).to have_logged_event(
            :proofing_agent_request,
            issuer: issuer,
            success: true,
            request_id:,
            request_type: :search_user,
          )
        end

        it 'includes request_id in the response' do
          action
          body = JSON.parse(response.body)
          expect(body['request_id']).to be_present
          expect(@analytics).to have_logged_event(
            :proofing_agent_request,
            issuer: issuer,
            success: true,
            request_id:,
            request_type: :search_user,
          )
        end
      end

      context 'with an invalid authorization header' do
        it_behaves_like 'an endpoint that requires authorization'
      end
    end
  end

  describe '#proof_user' do
    let(:action) { post :proof_user }

    context 'when proofing agent is not enabled' do
      it 'returns 404' do
        expect(action.status).to eq(404)
      end
    end

    context 'when proofing agent is enabled' do
      let(:enabled) { true }

      context 'with a valid authorization header' do
        it 'returns 200' do
          expect(action.status).to eq(200)
          expect(@analytics).to have_logged_event(
            :proofing_agent_request,
            issuer: issuer,
            success: true,
            request_id:,
            request_type: :proof_user,
          )
        end

        it 'includes request_id in the response' do
          action
          body = JSON.parse(response.body)
          expect(body['request_id']).to be_present
          expect(@analytics).to have_logged_event(
            :proofing_agent_request,
            issuer: issuer,
            success: true,
            request_id:,
            request_type: :proof_user,
          )
        end
      end

      context 'with an invalid authorization header' do
        it_behaves_like 'an endpoint that requires authorization'
      end
    end
  end
end
