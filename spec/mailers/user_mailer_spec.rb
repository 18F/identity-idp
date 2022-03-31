require 'rails_helper'

describe UserMailer, type: :mailer do
  let(:user) { build(:user) }
  let(:email_address) { user.email_addresses.first }
  let(:banned_email) { 'banned_email+123abc@gmail.com' }

  describe '#email_deleted' do
    let(:mail) { UserMailer.email_deleted(user, 'old@email.com') }

    it_behaves_like 'a system email'
    it_behaves_like 'an email that respects user email locale preference'

    it 'sends to the old email' do
      expect(mail.to).to eq ['old@email.com']
    end

    it 'renders the subject' do
      expect(mail.subject).to eq t('user_mailer.email_deleted.subject')
    end

    it 'renders the body' do
      expect(mail.html_part.body).to have_content(
        t('user_mailer.email_deleted.header', app_name: APP_NAME),
      )
      expect_email_body_to_have_help_and_contact_links
    end

    it 'does not send mail to emails in nonessential email banlist' do
      mail = UserMailer.email_deleted(user, banned_email)
      expect(mail.to).to eq(nil)
    end
  end

  describe '#password_changed' do
    let(:mail) { UserMailer.password_changed(user, email_address, disavowal_token: '123abc') }

    it_behaves_like 'a system email'
    it_behaves_like 'an email that respects user email locale preference'

    it 'sends to the current email' do
      expect(mail.to).to eq [email_address.email]
    end

    it 'renders the subject' do
      expect(mail.subject).to eq t('devise.mailer.password_updated.subject')
    end

    it 'renders the body' do
      expect(mail.html_part.body).to have_content(
        t('user_mailer.password_changed.intro_html', app_name: APP_NAME),
      )
      expect(mail.html_part.body).to include(
        '/events/disavow?disavowal_token=123abc',
      )
      expect_email_body_to_have_help_and_contact_links
    end

    it 'does not send mail to emails in nonessential email banlist' do
      email_address = EmailAddress.new(email: banned_email)
      mail = UserMailer.password_changed(user, email_address, disavowal_token: '123abc')
      expect(mail.to).to eq(nil)
    end
  end

  describe '#personal_key_sign_in' do
    let(:mail) { UserMailer.personal_key_sign_in(user, user.email, disavowal_token: 'asdf1234') }

    it_behaves_like 'a system email'
    it_behaves_like 'an email that respects user email locale preference'

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

    it 'does not send mail to emails in nonessential email banlist' do
      mail = UserMailer.personal_key_sign_in(user, banned_email, disavowal_token: 'asdf1234')
      expect(mail.to).to eq(nil)
    end
  end

  describe '#email_confirmation_instructions' do
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
    it_behaves_like 'an email that respects user email locale preference'
  end

  describe '#new_device_sign_in' do
    date = 'February 25, 2019 15:02'
    location = 'Washington, DC'
    disavowal_token = 'asdf1234'
    let(:mail) do
      UserMailer.new_device_sign_in(
        user: user,
        email_address: email_address,
        date: date,
        location: location,
        disavowal_token: disavowal_token,
      )
    end

    it_behaves_like 'a system email'

    it 'sends to the current email' do
      expect(mail.to).to eq [user.email]
    end

    it 'renders the subject' do
      expect(mail.subject).to eq t('user_mailer.new_device_sign_in.subject', app_name: APP_NAME)
    end

    it 'renders the body' do
      expect(mail.html_part.body).
        to have_content(
          strip_tags(
            t(
              'user_mailer.new_device_sign_in.info_html',
              date: date, location: location, app_name: APP_NAME,
            ),
          ),
        )
      expect(mail.html_part.body).to include(
        '/events/disavow?disavowal_token=asdf1234',
      )
      expect_email_body_to_have_help_and_contact_links
    end

    it 'does not send mail to emails in nonessential email banlist' do
      email_address = EmailAddress.new(email: banned_email)
      mail = UserMailer.new_device_sign_in(
        user: user,
        email_address: email_address,
        date: date,
        location: location,
        disavowal_token: disavowal_token,
      )
      expect(mail.to).to eq(nil)
    end
  end

  describe '#personal_key_regenerated' do
    let(:mail) { UserMailer.personal_key_regenerated(user, user.email) }

    it_behaves_like 'a system email'
    it_behaves_like 'an email that respects user email locale preference'

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

    it 'does not send mail to emails in nonessential email banlist' do
      mail = UserMailer.personal_key_regenerated(user, banned_email)
      expect(mail.to).to eq(nil)
    end
  end

  describe '#signup_with_your_email' do
    let(:mail) { UserMailer.signup_with_your_email(user, user.email) }

    it_behaves_like 'a system email'
    it_behaves_like 'an email that respects user email locale preference'

    it 'sends to the current email' do
      expect(mail.to).to eq [user.email]
    end

    it 'renders the subject' do
      expect(mail.subject).to eq t('mailer.email_reuse_notice.subject')
    end

    it 'renders the body' do
      expect(mail.html_part.body).to have_content(
        I18n.t(
          'user_mailer.signup_with_your_email.intro_html',
          app_name: APP_NAME,
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

  describe '#phone_added' do
    disavowal_token = 'i_am_disavowal_token'
    let(:mail) { UserMailer.phone_added(user, email_address, disavowal_token: disavowal_token) }

    it_behaves_like 'a system email'
    it_behaves_like 'an email that respects user email locale preference'

    it 'sends to the current email' do
      expect(mail.to).to eq [email_address.email]
    end

    it 'renders the subject' do
      expect(mail.subject).to eq t('user_mailer.phone_added.subject')
    end

    it 'renders the body' do
      expect(mail.html_part.body).to have_content(
        t('user_mailer.phone_added.intro', app_name: APP_NAME),
      )
    end

    it 'does not send mail to emails in nonessential email banlist' do
      email_address = EmailAddress.new(email: banned_email)
      mail = UserMailer.phone_added(user, email_address, disavowal_token: disavowal_token)
      expect(mail.to).to eq(nil)
    end
  end

  describe '#account_does_not_exist' do
    let(:mail) { UserMailer.account_does_not_exist('test@test.com', 'request_id') }

    it_behaves_like 'a system email'

    it 'sends to the current email' do
      expect(mail.to).to eq ['test@test.com']
    end

    it 'renders the subject' do
      expect(mail.subject).to eq t('user_mailer.account_does_not_exist.subject', app_name: APP_NAME)
    end

    it 'renders the body' do
      expect(mail.html_part.body).to have_content(
        t('user_mailer.account_does_not_exist.intro_html', app_name: APP_NAME),
      )
      expect(mail.html_part.body).to have_link(
        t('user_mailer.account_does_not_exist.link_text'),
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

  describe '#account_reset_request' do
    let(:mail) { UserMailer.account_reset_request(user, email_address, account_reset) }
    let(:account_reset) { user.account_reset_request }

    it_behaves_like 'a system email'
    it_behaves_like 'an email that respects user email locale preference'

    it 'sends to the current email' do
      expect(mail.to).to eq [email_address.email]
    end

    it 'renders the subject' do
      expect(mail.subject).to eq t('user_mailer.account_reset_request.subject', app_name: APP_NAME)
    end

    it 'renders the body' do
      expect(mail.html_part.body).to have_content(
        strip_tags(
          t('user_mailer.account_reset_request.intro_html', app_name: APP_NAME),
        ),
      )
    end

    it 'does not render the subject in the body' do
      expect(mail.html_part.body).not_to have_content(
        strip_tags(
          t('user_mailer.account_reset_request.subject', app_name: APP_NAME),
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

  describe '#account_reset_granted' do
    let(:mail) { UserMailer.account_reset_granted(user, email_address, user.account_reset_request) }

    it_behaves_like 'a system email'
    it_behaves_like 'an email that respects user email locale preference'

    it 'sends to the current email' do
      expect(mail.to).to eq [email_address.email]
    end

    it 'renders the subject' do
      expect(mail.subject).to eq t('user_mailer.account_reset_granted.subject', app_name: APP_NAME)
    end

    it 'renders the body' do
      expect(mail.html_part.body).to \
        have_content(
          strip_tags(t('user_mailer.account_reset_granted.intro_html', app_name: APP_NAME)),
        )
    end
  end

  describe '#account_reset_complete' do
    let(:mail) { UserMailer.account_reset_complete(user, email_address) }

    it_behaves_like 'a system email'
    it_behaves_like 'an email that respects user email locale preference'

    it 'sends to the current email' do
      expect(mail.to).to eq [email_address.email]
    end

    it 'renders the subject' do
      expect(mail.subject).to eq t('user_mailer.account_reset_complete.subject')
    end

    it 'renders the body' do
      expect(mail.html_part.body).
        to have_content(
          strip_tags(t('user_mailer.account_reset_complete.intro_html', app_name: APP_NAME)),
        )
    end
  end

  describe '#please_reset_password' do
    let(:mail) { UserMailer.please_reset_password(user, email_address.email) }

    it_behaves_like 'a system email'
    it_behaves_like 'an email that respects user email locale preference'

    it 'sends to the current email' do
      expect(mail.to).to eq [email_address.email]
    end

    it 'renders the subject' do
      expect(mail.subject).to eq t('user_mailer.please_reset_password.subject', app_name: APP_NAME)
    end

    it 'renders the body' do
      expect(mail.html_part.body).
        to have_content(
          strip_tags(t('user_mailer.please_reset_password.intro', app_name: APP_NAME)),
        )

      expect(mail.html_part.body).
        to have_content(strip_tags(t('user_mailer.please_reset_password.call_to_action')))
    end
  end

  describe '#doc_auth_desktop_link_to_sp' do
    let(:app) { 'login.gov' }
    let(:link) { root_url }
    let(:mail) { UserMailer.doc_auth_desktop_link_to_sp(user, email_address.email, app, link) }

    it_behaves_like 'a system email'
    it_behaves_like 'an email that respects user email locale preference'

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

  describe '#letter_reminder' do
    let(:mail) { UserMailer.letter_reminder(user, email_address.email) }

    it_behaves_like 'a system email'
    it_behaves_like 'an email that respects user email locale preference'

    it 'sends to the current email' do
      expect(mail.to).to eq [email_address.email]
    end

    it 'renders the subject' do
      expect(mail.subject).to eq t('user_mailer.letter_reminder.subject')
    end

    it 'renders the body' do
      expect(mail.html_part.body).
        to have_content(strip_tags(t('user_mailer.letter_reminder.info_html', link: APP_NAME)))
    end

    it 'does not send mail to emails in nonessential email banlist' do
      mail = UserMailer.letter_reminder(user, banned_email)
      expect(mail.to).to eq(nil)
    end
  end

  describe '#sps_over_quota_limit' do
    let(:mail) { UserMailer.sps_over_quota_limit(email_address.email) }

    it_behaves_like 'a system email'

    it 'sends to the current email' do
      expect(mail.to).to eq [email_address.email]
    end

    it 'renders the subject' do
      expect(mail.subject).to eq t('user_mailer.sps_over_quota_limit.subject')
    end

    it 'renders the body' do
      expect(mail.html_part.body).
        to have_content(strip_tags(t('user_mailer.sps_over_quota_limit.info')))
    end
  end

  describe 'deleted_user_accounts_report' do
    let(:mail) do
      UserMailer.deleted_user_accounts_report(
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
      expect(mail.subject).to eq t('user_mailer.deleted_accounts_report.subject')
    end

    it 'renders the body' do
      expect(mail.html_part.body).to have_content('my name')
      expect(mail.html_part.body).to have_content('issuer1')
      expect(mail.html_part.body).to have_content('issuer2')
    end
  end

  describe '#account_verified' do
    disavowal_token = 'i_am_disavowal_token'
    let(:sp_name) { '' }
    let(:date_time) { Time.zone.now }
    let(:mail) do
      UserMailer.account_verified(
        user, email_address, date_time: date_time, sp_name: sp_name,
                             disavowal_token: disavowal_token
      )
    end

    it_behaves_like 'a system email'
    it_behaves_like 'an email that respects user email locale preference'

    it 'sends to the current email' do
      expect(mail.to).to eq [email_address.email]
    end

    it 'renders the subject' do
      expect(mail.subject).to eq t('user_mailer.account_verified.subject', sp_name: sp_name)
    end

    it 'does not send mail to emails in nonessential email banlist' do
      email_address = EmailAddress.new(email: banned_email)
      mail = UserMailer.account_verified(
        user, email_address, date_time: date_time, sp_name: sp_name,
                             disavowal_token: disavowal_token
      )
      expect(mail.to).to eq(nil)
    end
  end

  def strip_tags(str)
    ActionController::Base.helpers.strip_tags(str)
  end
end
