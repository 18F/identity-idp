require 'rails_helper'

RSpec.describe Users::SmsPreviewController do
  describe '#show' do
    it 'redirects to SMS preview page in actionmailer' do
      allow(IdentityConfig.store).to receive(:rails_mailer_previews_enabled).and_return(true)
      get :show

      expect(response.location).to eq('http://www.example.com/rails/mailers/sms_text_mailer')
    end
  end
end
