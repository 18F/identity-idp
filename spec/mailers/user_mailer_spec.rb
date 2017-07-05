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
      expect_email_body_to_have_help_and_contact_links
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
      expect_email_body_to_have_help_and_contact_links
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
      expect_email_body_to_have_help_and_contact_links
    end

    context 'in a non-default locale' do
      before { I18n.locale = :fr }

      it 'links to the correct locale' do
        expect(mail.html_part.body).to include(root_url(locale: :fr))
      end
    end
  end

  describe 'phone_changed' do
    let(:mail) { UserMailer.phone_changed(user) }

    it_behaves_like 'a system email'

    it 'sends to the current email' do
      expect(mail.to).to eq [user.email]
    end

    it 'renders the subject' do
      expect(mail.subject).to eq t('user_mailer.phone_changed.subject')
    end

    it 'renders the body' do
      expect(mail.html_part.body).to have_content(
        t('user_mailer.phone_changed.intro', app: APP_NAME)
      )
      expect_email_body_to_have_help_and_contact_links
    end
  end

  def expect_email_body_to_have_help_and_contact_links
    expect(mail.html_part.body).to have_link(
      t('user_mailer.help_link_text'), href: MarketingSite.help_url
    )
    expect(mail.html_part.body).to have_link(
      t('user_mailer.contact_link_text'), href: MarketingSite.contact_url
    )
  end
end
