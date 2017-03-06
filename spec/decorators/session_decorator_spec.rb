require 'rails_helper'

RSpec.describe SessionDecorator do
  subject { SessionDecorator.new }

  it 'has the same public API as ServiceProviderSessionDecorator' do
    ServiceProviderSessionDecorator.public_instance_methods.each do |method|
      expect(
        described_class.public_method_defined?(method)
      ).to be(true), "expected #{described_class} to have ##{method}"
    end
  end

  describe '#return_to_service_provider_partial' do
    it 'returns the correct partial' do
      expect(subject.return_to_service_provider_partial).to eq 'shared/null'
    end
  end

  describe '#nav_partial' do
    it 'returns the correct partial' do
      expect(subject.nav_partial).to eq 'shared/nav_lite'
    end
  end

  describe '#new_session_heading' do
    it 'returns the correct string' do
      expect(subject.new_session_heading).to eq I18n.t('headings.sign_in_without_sp')
    end
  end

  describe '#registration_heading' do
    it 'returns the correct string' do
      expect(subject.registration_heading).to eq I18n.t('headings.create_account_without_sp')
    end
  end

  describe '#idv_hardfail4_partial' do
    it 'returns the correct partial' do
      expect(subject.idv_hardfail4_partial).to eq 'shared/null'
    end
  end

  describe '#logo_partial' do
    it 'returns nil' do
      expect(subject.logo_partial).to be_nil
    end
  end

  describe '#timeout_flash_text' do
    it 'returns the correct string' do
      expect(subject.timeout_flash_text).to eq(
        t('notices.session_cleared', minutes: Figaro.env.session_timeout_in_minutes)
      )
    end
  end

  describe '#sp_name' do
    it 'returns nil' do
      expect(subject.sp_name).to be_nil
    end
  end
end
