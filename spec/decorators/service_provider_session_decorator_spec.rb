require 'rails_helper'

RSpec.describe ServiceProviderSessionDecorator do
  it 'has the same public API as SessionDecorator' do
    SessionDecorator.public_instance_methods.each do |method|
      expect(
        described_class.public_method_defined?(method)
      ).to be(true), "expected #{described_class} to have ##{method}"
    end
  end

  describe '#return_to_service_provider_partial' do
    it 'returns the correct partial' do
      expect(decorator.return_to_service_provider_partial).to eq(
        'devise/sessions/return_to_service_provider'
      )
    end
  end

  describe '#nav_partial' do
    it 'returns the correct partial' do
      expect(decorator.nav_partial).to eq 'shared/nav_branded'
    end
  end

  describe '#new_session_heading' do
    it 'returns the correct string' do
      expect(decorator.new_session_heading).to eq I18n.t('headings.sign_in_with_sp', sp: sp_name)
    end
  end

  describe '#registration_heading' do
    it 'returns the correct string' do
      expect(decorator.registration_heading).to eq(
        I18n.t('headings.create_account_with_sp', sp: sp_name)
      )
    end
  end

  describe '#registration_bullet_1' do
    it 'returns the correct string' do
      expect(decorator.registration_bullet_1).to eq(
        I18n.t('devise.registrations.start.bullet_1_with_sp', sp: sp_name)
      )
    end
  end

  describe '#idv_hardfail4_partial' do
    it 'returns the correct partial' do
      expect(decorator.idv_hardfail4_partial).to eq 'verify/hardfail4'
    end
  end

  describe '#logo_partial' do
    context 'logo present' do
      it 'returns branded logo partial' do
        decorator = ServiceProviderSessionDecorator.new(sp_name: 'Test', sp_logo: 'logo')

        expect(decorator.logo_partial).to eq 'shared/nav_branded_logo'
      end
    end

    context 'logo not present' do
      it 'is null' do
        decorator = ServiceProviderSessionDecorator.new(sp_name: 'Test', sp_logo: nil)

        expect(decorator.logo_partial).to eq 'shared/null'
      end
    end
  end

  def decorator
    ServiceProviderSessionDecorator.new(sp_name: sp_name, sp_logo: nil)
  end

  def sp_name
    'Best SP ever!'
  end
end
