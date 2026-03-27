# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::ProofingAgent::ProofingAgentController do
  let(:enabled) { false }
  let(:headers) do
    {
      'X-Proofing-Location-Id' => 'loc-123',
      'X-Agent-Id' => 'agent-456',
      'X-Request-Id' => 'req-789',
    }
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

      it 'returns the X-Request-Id header as request_id' do
        action
        body = JSON.parse(response.body)
        expect(body['request_id']).to eq('req-789')
      end

      context 'without X-Proofing-Location-Id header' do
        let(:headers) { { 'X-Agent-Id' => 'agent-456', 'X-Request-Id' => 'req-789' } }

        it 'returns 400' do
          expect(action.status).to eq(400)
        end
      end

      context 'without X-Agent-Id header' do
        let(:headers) { { 'X-Proofing-Location-Id' => 'loc-123', 'X-Request-Id' => 'req-789' } }

        it 'returns 400' do
          expect(action.status).to eq(400)
        end
      end

      context 'without X-Request-Id header' do
        let(:headers) { { 'X-Proofing-Location-Id' => 'loc-123', 'X-Agent-Id' => 'agent-456' } }

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
          expect(body['error']).to include('X-Proofing-Location-Id')
          expect(body['error']).to include('X-Agent-Id')
          expect(body['error']).to include('X-Request-Id')
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

      it 'returns the X-Request-Id header as request_id' do
        action
        body = JSON.parse(response.body)
        expect(body['request_id']).to eq('req-789')
      end

      context 'without X-Proofing-Location-Id header' do
        let(:headers) { { 'X-Agent-Id' => 'agent-456', 'X-Request-Id' => 'req-789' } }

        it 'returns 400' do
          expect(action.status).to eq(400)
        end
      end

      context 'without X-Agent-Id header' do
        let(:headers) { { 'X-Proofing-Location-Id' => 'loc-123', 'X-Request-Id' => 'req-789' } }

        it 'returns 400' do
          expect(action.status).to eq(400)
        end
      end

      context 'without X-Request-Id header' do
        let(:headers) { { 'X-Proofing-Location-Id' => 'loc-123', 'X-Agent-Id' => 'agent-456' } }

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
