require 'rails_helper'

MockAhoy = Struct.new(:visit_token, :visitor_token)

RSpec.describe Ahoy::Store do
  context 'visit_token is an invalid UUID' do
    it 'excludes the event' do
      mock_ahoy = MockAhoy.new('foo', '1056d484-194c-4b8c-978d-0c0f57958f04')
      store = Ahoy::Store.new(ahoy: mock_ahoy)

      expect(store.exclude?).to eq true
    end
  end

  context 'visitor_token is an invalid UUID' do
    it 'excludes the event' do
      mock_ahoy = MockAhoy.new('1056d484-194c-4b8c-978d-0c0f57958f04', 'foo')
      store = Ahoy::Store.new(ahoy: mock_ahoy)

      expect(store.exclude?).to eq true
    end
  end

  context 'visitor_token is a string with invalid UTF-8 bytes' do
    it 'excludes the event' do
      mock_ahoy = MockAhoy.new("foo\255", "bar\255")
      store = Ahoy::Store.new(ahoy: mock_ahoy)

      expect(store.exclude?).to eq true
    end
  end

  context 'both visitor_token and visit_token are a valid UUID' do
    it 'does not exclude the event' do
      mock_ahoy = MockAhoy.new(
        '1056d484-194c-4b8c-978d-0c0f57958f04', '1056d484-194c-4b8c-978d-0c0f57958f04'
      )
      store = Ahoy::Store.new(ahoy: mock_ahoy)

      expect(store.exclude?).to eq false
    end
  end

  context 'FeatureManagement.enable_load_testing_mode? is true' do
    it 'does not exclude the event' do
      allow(FeatureManagement).to receive(:enable_load_testing_mode?).and_return(true)
      store = Ahoy::Store.new({})

      expect(store.exclude?).to be_nil
    end
  end

  context 'FeatureManagement.use_dashboard_service_providers? is true' do
    it 'does not exclude the event' do
      allow(FeatureManagement).to receive(:use_dashboard_service_providers?).
        and_return(true)
      store = Ahoy::Store.new({})

      expect(store.exclude?).to be_nil
    end
  end
end
