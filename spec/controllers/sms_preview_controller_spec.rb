require 'rails_helper'

RSpec.describe SmsPreviewController do
  describe '#show' do
    it 'redirects to SMS preview page in actionmailer' do
      allow(IdentityConfig.store).to receive(:rails_mailer_previews_enabled) { true }
      get :show

      expect(response).to redirect_to '/rails/mailers/sms_text_mailer'
    end
  end
end
