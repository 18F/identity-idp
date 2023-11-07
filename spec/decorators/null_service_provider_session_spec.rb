require 'rails_helper'

RSpec.describe NullServiceProviderSession do
  subject { NullServiceProviderSession.new }

  describe '#new_session_heading' do
    it 'returns the correct string' do
      expect(subject.new_session_heading).to eq I18n.t('headings.sign_in_without_sp')
    end
  end

  describe '#verification_method_choice' do
    it 'returns the correct string' do
      expect(subject.verification_method_choice).to eq(
        I18n.t('idv.messages.select_verification_without_sp'),
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
      null_sp_session = NullServiceProviderSession.new(view_context:)

      expect(null_sp_session.cancel_link_url).to eq 'http://www.example.com'
    end
  end

  describe '#mfa_expiration_interval' do
    it 'returns the AAL1 expiration interval' do
      expect(subject.mfa_expiration_interval).to eq(30.days)
    end
  end

  describe '#requested_more_recent_verification' do
    it 'is false' do
      expect(subject.requested_more_recent_verification?).to eq(false)
    end
  end
end
