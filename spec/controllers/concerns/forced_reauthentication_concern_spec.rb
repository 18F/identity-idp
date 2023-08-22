require 'rails_helper'

RSpec.describe ForcedReauthenticationConcern do
  let(:test_class) do
    Class.new do
      include ForcedReauthenticationConcern

      attr_reader :session

      def initialize(session = {})
        @session = session
      end
    end
  end
  let(:instance) { test_class.new }

  describe '#issuer_forced_reauthentication?' do
    it 'returns true if issuer has forced reauthentication' do
      instance.set_issuer_forced_reauthentication(
        issuer: 'test_issuer',
        is_forced_reauthentication: true,
      )
      expect(instance.issuer_forced_reauthentication?(issuer: 'test_issuer')).to eq true
    end

    it 'returns false if issuer has not forced reauthentication' do
      expect(instance.issuer_forced_reauthentication?(issuer: 'test_issuer')).to eq false
    end

    it 'returns false if forced reauthentication is set to false for an issuer' do
      instance.set_issuer_forced_reauthentication(
        issuer: 'test_issuer',
        is_forced_reauthentication: false,
      )
      expect(instance.issuer_forced_reauthentication?(issuer: 'test_issuer')).to eq false
    end

    it 'returns false if issuer sets forced reauthentication to true and then false' do
      instance.set_issuer_forced_reauthentication(
        issuer: 'test_issuer',
        is_forced_reauthentication: true,
      )
      instance.set_issuer_forced_reauthentication(
        issuer: 'test_issuer',
        is_forced_reauthentication: false,
      )
      expect(instance.issuer_forced_reauthentication?(issuer: 'test_issuer')).to eq false
    end
  end
end
