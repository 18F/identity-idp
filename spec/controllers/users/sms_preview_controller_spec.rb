require 'rails_helper'

RSpec.describe Users::SmsPreviewController do
  describe '#show' do
    it 'redirects to SMS preview page in actionmailer' do
      get :show

      expect(response.location).to eq('http://www.example.com/rails/mailers/sms_text_mailer')
    end
  end
end
