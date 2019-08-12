require 'rails_helper'

# rubocop:disable Style/BracesAroundHashParameters

RSpec.describe Health::JobsController do
  describe '#index' do
    subject(:action) { get :index }

    context 'when jobs are healthy' do
      it 'returns healthy' do
        allow(JobRunner::HealthChecker).to receive(:check).
          and_return(JobRunner::HealthChecker::Summary.new(true, { 'foo' => true }))

        action

        expect(response.status).to eq(200)

        json = JSON.parse(response.body)

        expect(json['healthy']).to eq(true)
        expect(json['result']).to eq({ 'foo' => true })
      end
    end

    context 'when jobs are unhealthy' do
      before do
        expect(JobRunner::HealthChecker).to receive(:check).
          and_return(JobRunner::HealthChecker::Summary.new(false, { 'foo' => false }))
      end

      it 'is a 500' do
        action

        expect(response.status).to eq(500)
      end

      it 'renders the error' do
        action

        json = JSON.parse(response.body, symbolize_names: true)

        expect(json[:healthy]).to eq(false)
        expect(json[:result]).to eq({ foo: false })
      end
    end
  end
end

# rubocop:enable Style/BracesAroundHashParameters
