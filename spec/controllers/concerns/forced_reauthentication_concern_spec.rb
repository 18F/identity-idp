require 'rails_helper'

RSpec.describe ForcedReauthenticationConcern do
  class TestClass
    include ForcedReauthenticationConcern

    attr_reader :session

    def initialize(session = {})
      @session = session
    end
  end

  describe '#issuer_forced_reauthentication?' do
    it 'returns true if issuer has forced reauthentication' do
      instance = TestClass.new
      instance.set_issuer_forced_reauthentication('test_issuer', true)
      expect(instance.issuer_forced_reauthentication?('test_issuer')).to eq true
    end

    it 'returns false if issuer has not forced reauthentication' do
      instance = TestClass.new
      expect(instance.issuer_forced_reauthentication?('test_issuer')).to eq false
    end

    it 'returns false if forced reauthentication is set to false for an issuer' do
      instance = TestClass.new
      instance.set_issuer_forced_reauthentication('test_issuer', false)
      expect(instance.issuer_forced_reauthentication?('test_issuer')).to eq false
    end

    it 'returns false if issuer sets forced reauthentication to true and then false' do
      instance = TestClass.new
      instance.set_issuer_forced_reauthentication('test_issuer', true)
      instance.set_issuer_forced_reauthentication('test_issuer', false)
      expect(instance.issuer_forced_reauthentication?('test_issuer')).to eq false
    end
  end
end
