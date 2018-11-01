require 'rails_helper'

RSpec.describe SessionDecorator do
  subject { SessionDecorator.new }

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
    it 'returns view_context.root url' do
      view_context = ActionController::Base.new.view_context
      allow(view_context).to receive(:root_url).and_return('http://www.example.com')
      decorator = SessionDecorator.new(view_context: view_context)

      expect(decorator.cancel_link_url).to eq 'http://www.example.com'
    end
  end

  describe '#mfa_expiration_interval' do
    it 'returns the AAL1 expiration interval' do
      expect(subject.mfa_expiration_interval).to eq(30.days)
    end
  end
end
