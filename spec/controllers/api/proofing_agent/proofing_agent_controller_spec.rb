# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::ProofingAgent::ProofingAgentController do
  let(:enabled) { false }

  before do
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

      it 'returns 200' do
        expect(action.status).to eq(200)
      end

      it 'includes request_id in the response' do
        action
        body = JSON.parse(response.body)
        expect(body['request_id']).to be_present
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
    end
  end
end
