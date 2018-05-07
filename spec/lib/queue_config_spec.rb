require 'rails_helper'

RSpec.describe Upaya::QueueConfig do
  describe '.choose_queue_adapter' do
    it 'raises ArgumentError given invalid choice' do
      expect(Figaro.env).to receive(:queue_adapter_weights).and_return('{"invalid": 1}')
      expect {
        Upaya::QueueConfig.choose_queue_adapter
      }.to raise_error(ArgumentError, /Unknown queue adapter/)
    end

    it 'handles sidekiq' do
      expect(Figaro.env).to receive(:queue_adapter_weights).and_return('{"sidekiq": 1}')
      expect(Upaya::QueueConfig.choose_queue_adapter).to eq :sidekiq
    end
    it 'handles async' do
      expect(Figaro.env).to receive(:queue_adapter_weights).and_return('{"async": 1, "sidekiq": 0}')
      expect(Upaya::QueueConfig.choose_queue_adapter).to eq :async
    end
    it 'handles inline' do
      expect(Figaro.env).to receive(:queue_adapter_weights).and_return('{"inline": 1}')
      expect(Upaya::QueueConfig.choose_queue_adapter).to eq :inline
    end
  end
end
