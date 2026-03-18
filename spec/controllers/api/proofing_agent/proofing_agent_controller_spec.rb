# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::ProofingAgent::ProofingAgentController do
  let(:enabled) { false }
  let(:headers) do
    { 'location-id' => 'loc-123', 'agent-id' => 'agent-456' }
  end

  before do
    allow(FeatureManagement).to receive(:idv_proofing_agent_enabled?).and_return(enabled)
    headers.each { |key, value| request.headers[key] = value }
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

      it 'returns 200' do
        expect(action.status).to eq(200)
      end

      it 'includes request_id in the response' do
        action
        body = JSON.parse(response.body)
        expect(body['request_id']).to be_present
      end

      context 'without location-id header' do
        let(:headers) { { 'agent-id' => 'agent-456' } }

        it 'returns 400' do
          expect(action.status).to eq(400)
        end
      end

      context 'without agent-id header' do
        let(:headers) { { 'location-id' => 'loc-123' } }

        it 'returns 400' do
          expect(action.status).to eq(400)
        end
      end

      context 'without any required headers' do
        let(:headers) { {} }

        it 'returns 400' do
          expect(action.status).to eq(400)
        end

        it 'lists missing headers in error' do
          action
          body = JSON.parse(response.body)
          expect(body['error']).to include('location-id')
          expect(body['error']).to include('agent-id')
        end
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

      it 'returns 200' do
        expect(action.status).to eq(200)
      end

      it 'includes request_id in the response' do
        action
        body = JSON.parse(response.body)
        expect(body['request_id']).to be_present
      end

      context 'without location-id header' do
        let(:headers) { { 'agent-id' => 'agent-456' } }

        it 'returns 400' do
          expect(action.status).to eq(400)
        end
      end

      context 'without agent-id header' do
        let(:headers) { { 'location-id' => 'loc-123' } }

        it 'returns 400' do
          expect(action.status).to eq(400)
        end
      end

      context 'without any required headers' do
        let(:headers) { {} }

        it 'returns 400' do
          expect(action.status).to eq(400)
        end
      end
    end
  end
end
