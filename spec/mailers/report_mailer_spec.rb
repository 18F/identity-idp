require 'rails_helper'

describe ReportMailer, type: :mailer do
  describe 'sps_over_quota_limit' do
    let(:email_address) { Faker::Internet.safe_email }
    let(:mail) { ReportMailer.sps_over_quota_limit(email_address) }

    it_behaves_like 'a system email'

    it 'sends to the current email' do
      expect(mail.to).to eq [email_address]
    end

    it 'renders the subject' do
      expect(mail.subject).to eq t('report_mailer.sps_over_quota_limit.subject')
    end

    it 'renders the body' do
      expect(mail.html_part.body).to have_content(
        ActionController::Base.helpers.strip_tags(t('report_mailer.sps_over_quota_limit.info'))
      )
    end
  end
end
