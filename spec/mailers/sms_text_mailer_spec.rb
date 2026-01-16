require 'rails_helper'

RSpec.describe SmsTextMailer, type: :mailer do
  describe 'text messages' do
    let(:mail) { SmsTextMailer.daily_voice_limit_reached }
    let(:user) { create(:user) }
    let(:email_address) { user.email_addresses.first }

    it 'renders the text message' do
      expect(mail.subject).to eq('Daily voice limit reached')
      expect(mail.to).to eq('NO EMAIL')
      expect(mail.from).to eq(['no-reply@login.gov'])
    end
  end
end
