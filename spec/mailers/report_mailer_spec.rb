require 'rails_helper'

RSpec.describe ReportMailer, type: :mailer do
  let(:user) { build(:user) }
  let(:email_address) { user.email_addresses.first }

  describe '#deleted_user_accounts_report' do
    let(:mail) do
      ReportMailer.deleted_user_accounts_report(
        email: email_address.email,
        name: 'my name',
        issuers: %w[issuer1 issuer2],
        data: 'data',
      )
    end

    it_behaves_like 'a system email'

    it 'sends to the current email' do
      expect(mail.to).to eq [email_address.email]
    end

    it 'renders the subject' do
      expect(mail.subject).to eq t('report_mailer.deleted_accounts_report.subject')
    end

    it 'renders the body' do
      expect(mail.html_part.body).to have_content('my name')
      expect(mail.html_part.body).to have_content('issuer1')
      expect(mail.html_part.body).to have_content('issuer2')
    end
  end

  describe '#warn_error' do
    let(:error) { RuntimeError.new('this is my test message') }
    let(:env) { ActiveSupport::StringInquirer.new('prod') }

    let(:mail) do
      ReportMailer.warn_error(
        email: 'test@example.com',
        error: error,
        env: env,
      )
    end

    it 'puts the rails env and error in a plaintext email', aggregate_failures: true do
      expect(mail.html_part).to be_nil

      expect(mail.subject).to include('prod')
      expect(mail.subject).to include('RuntimeError')

      expect(mail.text_part.body).to include('this is my test')
    end
  end
end
