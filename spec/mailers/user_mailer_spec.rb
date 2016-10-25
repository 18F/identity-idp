require 'rails_helper'

describe UserMailer, type: :mailer do
  let(:user) { build_stubbed(:user) }

  describe 'email_changed' do
    let(:mail) { UserMailer.email_changed('old@email.com') }

    it_behaves_like 'a system email'

    it 'sends to the old email' do
      expect(mail.to).to eq ['old@email.com']
    end

    it 'renders the subject' do
      expect(mail.subject).to eq t('mailer.email_change_notice.subject')
    end

    it 'renders the body' do
      expect(mail.html_part.body).
        to have_content(
          "You have asked #{APP_NAME} to change the email address currently associated with your " \
          "#{APP_NAME} Account"
        )
    end
  end

  describe 'password_changed' do
    let(:mail) { UserMailer.password_changed(user) }

    it_behaves_like 'a system email'

    it 'sends to the current email' do
      expect(mail.to).to eq [user.email]
    end

    it 'renders the subject' do
      expect(mail.subject).to eq t('devise.mailer.password_updated.subject')
    end

    it 'renders the body' do
      expect(mail.html_part.body).
        to have_content(
          "You have asked #{APP_NAME} to change the password currently associated with your " \
          "#{APP_NAME} Account"
        )
    end
  end

  describe 'signup_with_your_email' do
    let(:mail) { UserMailer.signup_with_your_email(user.email) }

    it_behaves_like 'a system email'

    it 'sends to the current email' do
      expect(mail.to).to eq [user.email]
    end

    it 'renders the subject' do
      expect(mail.subject).to eq t('mailer.email_reuse_notice.subject')
    end

    it 'renders the body' do
      expect(mail.html_part.body).to have_content('This email address is already in use.')
    end
  end

  describe 'contact_request' do
    details = {
      'want_learn' => '1',
      'want_tell' => '0',
      'email_or_tel' => 'thomas jefferson',
      'comments' => 'usa!'
    }

    let(:mail) { UserMailer.contact_request(details) }

    it_behaves_like 'a system email'

    it 'sends to the current email' do
      expect(mail.to).to eq [Figaro.env.support_email]
    end

    it 'renders the subject' do
      expect(mail.subject).to eq t('mailer.contact_request.subject')
    end

    it 'renders the body' do
      expect(mail.html_part.body).
        to have_content("Email or phone:#{details['email_or_tel']}")

      expect(mail.html_part.body).
        to have_content("Comments:#{details['comments']}")
    end
  end
end
