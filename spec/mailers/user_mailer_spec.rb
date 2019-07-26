require 'rails_helper'

describe UserMailer, type: :mailer do
  let(:user) { build(:user) }
  let(:email_address) { user.email_addresses.first }

  describe 'email_deleted' do
    let(:mail) { UserMailer.email_deleted('old@email.com') }

    it_behaves_like 'a system email'

    it 'sends to the old email' do
      expect(mail.to).to eq ['old@email.com']
    end

    it 'renders the subject' do
      expect(mail.subject).to eq t('user_mailer.email_deleted.subject')
    end

    it 'renders the body' do
      expect(mail.html_part.body).to have_content(
        t('user_mailer.email_deleted.header', app: APP_NAME),
      )
      expect_email_body_to_have_help_and_contact_links
    end
  end

  describe 'password_changed' do
    let(:mail) { UserMailer.password_changed(email_address, disavowal_token: '123abc') }

    it_behaves_like 'a system email'

    it 'sends to the current email' do
      expect(mail.to).to eq [email_address.email]
    end

    it 'renders the subject' do
      expect(mail.subject).to eq t('devise.mailer.password_updated.subject')
    end

    it 'renders the body' do
      expect(mail.html_part.body).to have_content(
        t('user_mailer.password_changed.intro', app: APP_NAME),
      )
      expect(mail.html_part.body).to include(
        '/events/disavow?disavowal_token=123abc',
      )
      expect_email_body_to_have_help_and_contact_links
    end
  end

  describe 'personal_key_sign_in' do
    let(:mail) { UserMailer.personal_key_sign_in(user.email, disavowal_token: 'asdf1234') }

    it_behaves_like 'a system email'

    it 'sends to the current email' do
      expect(mail.to).to eq [user.email]
    end

    it 'renders the subject' do
      expect(mail.subject).to eq t('user_mailer.personal_key_sign_in.subject')
    end

    it 'renders the body' do
      expect(mail.html_part.body).to have_content(
        t('user_mailer.personal_key_sign_in.intro'),
      )
      expect(mail.html_part.body).to include(
        '/events/disavow?disavowal_token=asdf1234',
      )
    end
  end

  describe 'email_confirmation_instructions' do
    let(:instructions) { 'do the things' }
    let(:request_id) { '1234-abcd' }
    let(:token) { 'asdf123' }

    let(:mail) do
      UserMailer.email_confirmation_instructions(
        user,
        user.email,
        token,
        request_id: request_id,
        instructions: instructions,
      )
    end

    it_behaves_like 'a system email'
  end

  describe 'sign in from new device' do
    date = 'Washington, DC'
    location = 'February 25, 2019 15:02'
    disavowal_token = 'asdf1234'
    let(:mail) { UserMailer.new_device_sign_in(email_address, date, location, disavowal_token) }

    it_behaves_like 'a system email'

    it 'sends to the current email' do
      expect(mail.to).to eq [user.email]
    end

    it 'renders the subject' do
      expect(mail.subject).to eq t('user_mailer.new_device_sign_in.subject')
    end

    it 'renders the body' do
      expect(mail.html_part.body).
        to have_content(strip_tags(t('user_mailer.new_device_sign_in.info_html',
                                     date: date, location: location)))
      expect(mail.html_part.body).to include(
        '/events/disavow?disavowal_token=asdf1234',
      )
      expect_email_body_to_have_help_and_contact_links
    end
  end

  describe 'personal_key_regenerated' do
    let(:mail) { UserMailer.personal_key_regenerated(user.email) }

    it_behaves_like 'a system email'

    it 'sends to the current email' do
      expect(mail.to).to eq [user.email]
    end

    it 'renders the subject' do
      expect(mail.subject).to eq t('user_mailer.personal_key_regenerated.subject')
    end

    it 'renders the body' do
      expect(mail.html_part.body).to have_content(
        t('user_mailer.personal_key_regenerated.intro'),
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
          app: APP_NAME,
        ),
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

  describe 'phone_added' do
    disavowal_token = 'i_am_disavowal_token'
    let(:mail) { UserMailer.phone_added(email_address, disavowal_token: disavowal_token) }

    it_behaves_like 'a system email'

    it 'sends to the current email' do
      expect(mail.to).to eq [email_address.email]
    end

    it 'renders the subject' do
      expect(mail.subject).to eq t('user_mailer.phone_added.subject')
    end

    it 'renders the body' do
      expect(mail.html_part.body).to have_content(
        t('user_mailer.phone_added.intro', app: APP_NAME),
      )
    end
  end

  describe 'account_does_not_exist' do
    let(:mail) { UserMailer.account_does_not_exist('test@test.com', 'request_id') }

    it_behaves_like 'a system email'

    it 'sends to the current email' do
      expect(mail.to).to eq ['test@test.com']
    end

    it 'renders the subject' do
      expect(mail.subject).to eq t('user_mailer.account_does_not_exist.subject')
    end

    it 'renders the body' do
      expect(mail.html_part.body).to have_content(
        t('user_mailer.account_does_not_exist.intro', app: APP_NAME),
      )
      expect(mail.html_part.body).to have_link(
        t('user_mailer.account_does_not_exist.link_text', app: APP_NAME),
        href: sign_up_email_url(request_id: 'request_id'),
      )
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

  describe 'account_reset_request' do
    let(:mail) { UserMailer.account_reset_request(email_address, account_reset) }
    let(:account_reset) { user.account_reset_request }

    it_behaves_like 'a system email'

    it 'sends to the current email' do
      expect(mail.to).to eq [email_address.email]
    end

    it 'renders the subject' do
      expect(mail.subject).to eq t('user_mailer.account_reset_request.subject')
    end

    it 'renders the body' do
      reset_text = t('user_mailer.account_reset_granted.cancel_link_text')
      expect(mail.html_part.body).to have_content(
        strip_tags(
          t('user_mailer.account_reset_request.intro', cancel_account_reset: reset_text),
        ),
      )
    end

    it 'does not render the subject in the body' do
      expect(mail.html_part.body).not_to have_content(
        strip_tags(
          t('user_mailer.account_reset_request.subject'),
        ),
      )
    end

    it 'renders the header within the body' do
      expect(mail.html_part.body).to have_content(
        strip_tags(
          t('user_mailer.account_reset_request.header'),
        ),
      )
    end
  end

  describe 'account_reset_granted' do
    let(:mail) { UserMailer.account_reset_granted(email_address, user.account_reset_request) }

    it_behaves_like 'a system email'

    it 'sends to the current email' do
      expect(mail.to).to eq [email_address.email]
    end

    it 'renders the subject' do
      expect(mail.subject).to eq t('user_mailer.account_reset_granted.subject')
    end

    it 'renders the body' do
      expect(mail.html_part.body).to \
        have_content(strip_tags(t('user_mailer.account_reset_granted.intro')))
    end
  end

  describe 'account_reset_complete' do
    let(:mail) { UserMailer.account_reset_complete(email_address) }

    it_behaves_like 'a system email'

    it 'sends to the current email' do
      expect(mail.to).to eq [email_address.email]
    end

    it 'renders the subject' do
      expect(mail.subject).to eq t('user_mailer.account_reset_complete.subject')
    end

    it 'renders the body' do
      expect(mail.html_part.body).
        to have_content(strip_tags(t('user_mailer.account_reset_complete.intro')))
    end
  end

  describe 'please_reset_password' do
    let(:mail) { UserMailer.please_reset_password(email_address.email, 'This is a test.') }

    it_behaves_like 'a system email'

    it 'sends to the current email' do
      expect(mail.to).to eq [email_address.email]
    end

    it 'renders the subject' do
      expect(mail.subject).to eq t('user_mailer.please_reset_password.subject')
    end

    it 'renders the body' do
      expect(mail.html_part.body).
        to have_content(strip_tags(t('user_mailer.please_reset_password.intro')))

      expect(mail.html_part.body).
        to have_content(strip_tags(t('user_mailer.please_reset_password.call_to_action')))

      expect(mail.html_part.body).
        to have_content('This is a test.')
    end
  end

  describe 'undeliverable_address' do
    let(:mail) { UserMailer.undeliverable_address(email_address) }

    it_behaves_like 'a system email'

    it 'sends to the current email' do
      expect(mail.to).to eq [email_address.email]
    end

    it 'renders the subject' do
      expect(mail.subject).to eq t('user_mailer.undeliverable_address.subject')
    end

    it 'renders the body' do
      expect(mail.html_part.body).
        to have_content(strip_tags(t('user_mailer.undeliverable_address.intro')))
    end
  end

  describe 'doc_auth_desktop_link_to_sp' do
    let(:app) { 'login.gov' }
    let(:link) { root_url }
    let(:mail) { UserMailer.doc_auth_desktop_link_to_sp(email_address.email, app, link) }

    it_behaves_like 'a system email'

    it 'sends to the current email' do
      expect(mail.to).to eq [email_address.email]
    end

    it 'renders the subject' do
      expect(mail.subject).to eq t('user_mailer.doc_auth_link.subject')
    end

    it 'renders the body' do
      expect(mail.html_part.body).to have_link(app, href: link)

      expect(mail.html_part.body).to \
        have_content(strip_tags(I18n.t('user_mailer.doc_auth_link.message', sp_link: nil)))
    end
  end

  describe 'expired letter' do
    let(:mail) { UserMailer.letter_expired(email_address.email) }

    it_behaves_like 'a system email'

    it 'sends to the current email' do
      expect(mail.to).to eq [email_address.email]
    end

    it 'renders the subject' do
      expect(mail.subject).to eq t('user_mailer.letter_expired.subject')
    end

    it 'renders the body' do
      expect(mail.html_part.body).
        to have_content(strip_tags(t('user_mailer.letter_expired.info', link: APP_NAME)))
    end
  end

  describe 'reminder letter' do
    let(:mail) { UserMailer.letter_reminder(email_address.email) }

    it_behaves_like 'a system email'

    it 'sends to the current email' do
      expect(mail.to).to eq [email_address.email]
    end

    it 'renders the subject' do
      expect(mail.subject).to eq t('user_mailer.letter_reminder.subject')
    end

    it 'renders the body' do
      expect(mail.html_part.body).
        to have_content(strip_tags(t('user_mailer.letter_reminder.info', link: APP_NAME)))
    end
  end

  def strip_tags(str)
    ActionController::Base.helpers.strip_tags(str)
  end
end
