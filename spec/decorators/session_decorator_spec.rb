require 'rails_helper'

RSpec.describe SessionDecorator do
  it 'has the same public API as ServiceProviderSessionDecorator' do
    ServiceProviderSessionDecorator.public_instance_methods.each do |method|
      expect(
        described_class.public_method_defined?(method)
      ).to be(true), "expected #{described_class} to have ##{method}"
    end
  end

  describe '#return_to_service_provider_partial' do
    it 'returns the correct partial' do
      expect(decorator.return_to_service_provider_partial).to eq 'shared/null'
    end
  end

  describe '#nav_partial' do
    it 'returns the correct partial' do
      expect(decorator.nav_partial).to eq 'shared/nav_lite'
    end
  end

  describe '#new_session_heading' do
    it 'returns the correct string' do
      expect(decorator.new_session_heading).to eq I18n.t('headings.sign_in_without_sp')
    end
  end

  describe '#registration_heading' do
    it 'returns the correct string' do
      expect(decorator.registration_heading).to eq I18n.t('headings.create_account_without_sp')
    end
  end

  describe '#registration_bullet_1' do
    it 'returns the correct string' do
      expect(decorator.registration_bullet_1).to eq(
        I18n.t('devise.registrations.start.bullet_1_without_sp')
      )
    end
  end

  describe '#idv_hardfail4_partial' do
    it 'returns the correct partial' do
      expect(decorator.idv_hardfail4_partial).to eq 'shared/null'
    end
  end

  def decorator
    SessionDecorator.new
  end
end
