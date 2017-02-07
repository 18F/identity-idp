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
      expect(mail.html_part.body).to have_content(
        t('user_mailer.email_changed.intro', app: APP_NAME)
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
      expect(mail.html_part.body).to have_content(
        t('user_mailer.password_changed.intro', app: APP_NAME)
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
      expect(mail.html_part.body).to have_content(
        I18n.t(
          'user_mailer.signup_with_your_email.intro',
          app: APP_NAME
        )
      )
    end
  end

  describe 'contact_request' do
    details = {
      'want_learn' => '1',
      'want_tell' => '0',
      'email_or_tel' => 'thomas jefferson',
      'comments' => 'usa!',
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
      expect(mail.html_part.body).to have_content(
        "#{t('user_mailer.contact_request.email_or_phone')}#{details['email_or_tel']}"
      )

      expect(mail.html_part.body).to have_content(
        "#{t('user_mailer.contact_request.want_to_learn')}#{t('user_mailer.contact_request.yes')}"
      )

      expect(mail.html_part.body).to have_content(
        "#{t('user_mailer.contact_request.talk_about_experience')}" \
        "#{t('user_mailer.contact_request.no')}"
      )

      expect(mail.html_part.body).to have_content(
        "#{t('user_mailer.contact_request.comments_header')}#{details['comments']}"
      )
    end
  end
end
