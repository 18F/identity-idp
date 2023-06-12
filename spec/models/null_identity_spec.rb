require 'rails_helper'

RSpec.describe NullIdentity do
  describe '#service_provider' do
    it 'uses constant' do
      expect(subject.service_provider).to eq NullIdentity::SERVICE_PROVIDER
    end
  end
end
