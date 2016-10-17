require 'rails_helper'

describe QueueHealthCheck do
  describe '#perform' do
    it 'enqueues jobs for each queue' do
      queues = QueueHealthCheck::QUEUES
      queues.each do |queue|
        allow(HealthCheck::CheckerJob).to receive(:perform_later).with(queue)
      end
      allow(HealthCheck::CheckerJob).to receive(:set).and_return(HealthCheck::CheckerJob)

      QueueHealthCheck.new.perform

      queues.each do |queue|
        expect(HealthCheck::CheckerJob).to have_received(:perform_later).with(queue)
      end
    end
  end
end
