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
    it 'returns the correct partial' do
      expect(subject.registration_heading).to eq 'sign_up/registrations/registration_heading'
    end
  end

  describe '#verification_method_choice' do
    it 'returns the correct string' do
      expect(subject.verification_method_choice).to eq(
        I18n.t('idv.messages.select_verification_without_sp')
      )
    end
  end

  describe '#idv_hardfail4_partial' do
    it 'returns the correct partial' do
      expect(subject.idv_hardfail4_partial).to eq 'idv/no_sp_hardfail'
    end
  end

  describe '#sp_logo' do
    it 'returns nil' do
      expect(subject.sp_logo).to be_nil
    end
  end

  describe '#sp_name' do
    it 'returns nil' do
      expect(subject.sp_name).to be_nil
    end
  end

  describe '#cancel_link_url' do
    it 'returns root url' do
      expect(subject.cancel_link_url).to eq 'http://www.example.com/'
    end
  end
end
