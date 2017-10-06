require 'rails_helper'

RSpec.describe Health::WorkersController do
  describe '#index' do
    before do
      allow(WorkerHealthChecker).to receive(:check).
        and_return(WorkerHealthChecker::Summary.new(statuses))
    end

    subject(:action) { get :index }

    let(:statuses) do
      [
        WorkerHealthChecker::Status.new('voice', 0.minutes.ago, true),
        WorkerHealthChecker::Status.new('sms', 0.minutes.ago, true),
      ]
    end

    it 'renders the responses as json' do
      action

      json = JSON.parse(response.body)

      expect(json['all_healthy']).to eq(true)
      expect(json['statuses'].first['queue']).to eq('voice')
      expect(json['statuses'].first['healthy']).to eq(true)
    end

    context 'with all healthy statuses' do
      it 'is a 200' do
        action

        expect(response.status).to eq(200)
      end
    end

    context 'with an unhealthy status' do
      let(:statuses) do
        [
          WorkerHealthChecker::Status.new('voice', 0.minutes.ago, true),
          WorkerHealthChecker::Status.new('sms', nil, false),
        ]
      end

      it 'is a 500' do
        action

        expect(response.status).to eq(500)
      end
    end
  end
end
