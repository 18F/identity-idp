require 'rails_helper'

RSpec.describe AbTests do
  describe '#all' do
    it 'returns all registered A/B tests' do
      expect(AbTests.all).to match(
        {
          ACUANT_SDK: an_instance_of(AbTest),
          DOC_AUTH_VENDOR: an_instance_of(AbTest),

        },
      )
    end
  end

  describe '#idv_session_discriminator' do
    let(:request) { spy }
    let(:user) { build(:user) }
    let(:user_session) { {} }
    let(:service_provider) {}

    subject(:discriminator) do
      AbTests.idv_session_discriminator do |idv_session|
        !!idv_session
      end.call(
        request:,
        user:,
        user_session:,
        service_provider:,
      )
    end

    it 'returns a discriminator value' do
      expect(discriminator).to be
    end

    context 'when user is nil' do
      let(:user) {}
      it 'returns nil' do
        expect(discriminator).to be_nil
      end
    end

    context 'when user_session is nil' do
      let(:user_session) {}
      it 'returns nil' do
        expect(discriminator).to be_nil
      end
    end
  end
end
