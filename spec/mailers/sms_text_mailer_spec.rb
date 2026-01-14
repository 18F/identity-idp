require 'rails_helper'

RSpec.describe SmsTextMailer, type: :mailer do
  describe 'daily_voice_limit_reached' do
    let(:mail) { SmsTextMailer.daily_voice_limit_reached }

    it 'renders the headers' do
      expect(mail.subject).to eq('Daily voice limit reached')
      expect(mail.to).to eq(['NO EMAIL'])
      expect(mail.from).to eq(['no-reply@login.gov'])
    end
  end
end
