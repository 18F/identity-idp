require 'rails_helper'

RSpec.describe TwoFactorAuthentication::MethodManager do
  let(:user) { build(:user) }
  let(:subject) { described_class.new(user) }
  let(:all_methods) { TwoFactorAuthentication::MethodManager::METHODS }

  describe '#configuration_managers' do
    let(:methods_count) { all_methods.count }

    let(:configuration_managers) { subject.configuration_managers }

    it 'returns one manager for each method' do
      expect(configuration_managers.count).to eq methods_count
      expect(all_methods - configuration_managers.map(&:method)).to eq []
      expect(configuration_managers.map(&:method) - all_methods).to eq []
    end
  end

  describe '#two_factor_enabled?' do
    context 'with piv/cac' do
      let(:user) { build(:user, :with_piv_or_cac) }

      it 'returns true for piv/cac' do
        expect(subject.two_factor_enabled?([:piv_cac])).to eq true
      end

      it 'returns true for any method enabled' do
        expect(subject.two_factor_enabled?).to eq true
      end

      (TwoFactorAuthentication::MethodManager::METHODS - [:piv_cac]).each do |method|
        it "returns false for #{method}" do
          expect(subject.two_factor_enabled?([method])).to eq false
        end

        it "returns true for [#{method}, piv_cac]" do
          expect(subject.two_factor_enabled?([method, :piv_cac])).to eq true
        end
      end
    end
  end

  describe '#two_factor_configurable?' do
    context 'with no phone configured' do
      it 'returns true that some method is configurable' do
        expect(subject.two_factor_configurable?).to eq true
      end

      it 'returns true that sms or voice is configurable' do
        expect(subject.two_factor_configurable?(%i[sms voice])).to eq true
      end
    end

    context 'with phone configured' do
      let(:user) { create(:user, :with_phone) }

      it 'returns true that some method is configurable' do
        expect(subject.two_factor_configurable?).to eq true
      end

      it 'returns false that sms or voice is configurable' do
        expect(subject.two_factor_configurable?(%i[sms voice])).to eq false
      end
    end

    context 'with all methods configured' do
      let(:user) do
        create(:user,
               :with_phone, :with_piv_or_cac, :with_personal_key, :with_authentication_app)
      end

      it 'returns false that some method is configurable' do
        expect(subject.two_factor_configurable?).to eq false
      end
    end
  end

  describe '#configurable_configuration_managers' do
    let(:configurable_methods) { subject.configurable_configuration_managers.map(&:method) }

    context 'with piv/cac and phone configured' do
      let(:user) { build(:user, :with_piv_or_cac, :with_phone) }

      it 'includes totp' do
        expect(configurable_methods).to include :totp
      end

      it 'excludes personal_key' do
        expect(configurable_methods).to_not include :personal_key
      end
    end

    context 'with no methods configured' do
      %i[voice sms].each do |preferred_otp|
        context "and #{preferred_otp} preferred" do
          let(:user) { build(:user, otp_delivery_preference: preferred_otp) }

          it "promotes #{preferred_otp}" do
            expect(configurable_methods.first).to eq preferred_otp
          end
        end
      end
    end
  end

  describe '#configuration_manager' do
    let(:user) { build(:user) }

    TwoFactorAuthentication::MethodManager::METHODS.each do |method|
      it "creates a configuration manager for #{method}" do
        manager = subject.configuration_manager(method)
        expect(manager).to be_a(TwoFactorAuthentication::ConfigurationManager)
        expect(manager.method).to eq method
      end
    end
  end
end
