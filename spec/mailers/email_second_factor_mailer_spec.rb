require 'rails_helper'

describe EmailSecondFactorMailer do
  describe 'your_code_is' do
    let(:user) { build_stubbed(:user, otp_secret_key: 'lzmh6ekrnc5i6aaq') }
    let(:mail) { EmailSecondFactorMailer.your_code_is(user) }

    it 'renders the subject' do
      expect(mail.subject).to eq('Secure one-time password notification')
    end

    it 'displays the code in the email' do
      expect(mail.body).to include("Please enter this secure one-time password: #{user.otp_code}")
    end

    it 'uses a default from address' do
      expect(mail.from).to eq ['upaya@18f.gov']
    end

    it 'includes a link to customer service in the email' do
      expect(mail.body).
        to include 'at <a href="https://upaya.18f.gov/contact">'
    end
  end
end
