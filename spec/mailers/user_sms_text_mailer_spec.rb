require 'rails_helper'

RSpec.describe UserSmsTextMailer, type: :mailer do
  context '#account_deleted_notice' do
    let(:mail) { UserSmsTextMailer.account_deleted_notice }

    it 'renders the text message' do
      expect(mail.subject).to eq('Account deleted notice')
      expect(mail.body.raw_source).to include(
        t(
          'telephony.account_deleted_notice',
          app_name: APP_NAME,
        ),
      )
    end
  end
end
