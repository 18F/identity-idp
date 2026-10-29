require 'rails_helper'

RSpec.describe UserMailer, type: :mailer do
  describe '#account_recovery_cancelled' do
    let(:user) { create(:user, :fully_registered) }
    let(:email_address) { user.confirmed_email_addresses.first }
    let(:mail) do
      described_class.with(user: user, email_address: email_address).account_recovery_cancelled
    end

    it_behaves_like 'a system email'
    it_behaves_like 'an email that respects user email locale preference'

    it 'confirms cancellation without implying the account was changed' do
      expect(mail.to).to eq([email_address.email])
      expect(mail.subject).to eq(
        t('user_mailer.account_recovery_cancelled.subject', app_name: APP_NAME),
      )
      expect(mail.html_part.body).to have_content(
        t('user_mailer.account_recovery_cancelled.intro', app_name: APP_NAME),
      )
      expect(mail.html_part.body).to have_content(
        t('user_mailer.account_recovery_cancelled.unrequested'),
      )
    end
  end
end
