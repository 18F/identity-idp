require 'rails_helper'

RSpec.describe Test::SmsPreviewController do
  describe '#show' do
    it 'redirects to SMS preview page in actionmailer' do
      get :show

      expect(response).to redirect_to('http://www.example.com/rails/mailers/sms_text_mailer')
    end
  end
end
