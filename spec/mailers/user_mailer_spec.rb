require 'rails_helper'

describe UserMailer, type: :mailer do
  let(:user) { build(:user) }
  let(:email_address) { user.email_addresses.first }
  let(:banned_email) { 'banned_email+123abc@gmail.com' }
  let(:banned_email_address) { create(:email_address, email: banned_email, user: user) }

  describe '#add_email' do
    let(:token) { SecureRandom.hex }
    let(:mail) { UserMailer.add_email(user, email_address, token) }

    it_behaves_like 'a system email'
    it_behaves_like 'an email that respects user email locale preference'

    it 'renders the add_email_confirmation_url' do
      add_email_url = add_email_confirmation_url(confirmation_token: token)

      expect(mail.html_part.body).to have_content(add_email_url)
      expect(mail.html_part.body).to_not have_content(sign_up_create_email_confirmation_url)
    end
  end

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
    let(:mail) do
      UserMailer.with(
        user: user,
        email_address: email_address,
      ).password_changed(disavowal_token: '123abc')
    end

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
      mail = UserMailer.with(user: user, email_address: banned_email_address).
        password_changed(disavowal_token: '123abc')
      expect(mail.to).to eq(nil)
    end
  end

  describe '#personal_key_sign_in' do
    let(:mail) do
      UserMailer.with(user: user, email_address: user.email_addresses.first).
        personal_key_sign_in(disavowal_token: 'asdf1234')
    end

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
      mail = UserMailer.with(user: user, email_address: banned_email_address).
        personal_key_sign_in(disavowal_token: 'asdf1234')

      expect(mail.to).to eq(nil)
    end
  end

  describe '#email_confirmation_instructions' do
    let(:instructions) { 'do the things' }
    let(:request_id) { '1234-abcd' }
    let(:token) { 'asdf123' }

    let(:mail) do
      UserMailer.with(user: user, email_address: user.email_addresses.first).
        email_confirmation_instructions(
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
      UserMailer.with(user: user, email_address: email_address).new_device_sign_in(
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
      mail = UserMailer.with(user: user, email_address: email_address).new_device_sign_in(
        date: date,
        location: location,
        disavowal_token: disavowal_token,
      )
      expect(mail.to).to eq(nil)
    end
  end

  describe '#personal_key_regenerated' do
    let(:mail) do
      UserMailer.with(user: user, email_address: email_address).personal_key_regenerated
    end

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
      mail = UserMailer.with(user: user, email_address: banned_email_address).
        personal_key_regenerated
      expect(mail.to).to eq(nil)
    end
  end

  describe '#signup_with_your_email' do
    let(:mail) do
      UserMailer.with(user: user, email_address: user.email_addresses.first).signup_with_your_email
    end

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
    let(:mail) do
      UserMailer.with(user: user, email_address: email_address).
        phone_added(disavowal_token: disavowal_token)
    end

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
      mail = UserMailer.with(user: user, email_address: banned_email_address).
        phone_added(disavowal_token: disavowal_token)
      expect(mail.to).to eq(nil)
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
    let(:mail) do
      UserMailer.with(user: user, email_address: email_address).account_reset_request(account_reset)
    end

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
    let(:mail) do
      UserMailer.with(user: user, email_address: email_address).
        account_reset_granted(user.account_reset_request)
    end

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

  describe '#in_person_ready_to_verify' do
    let!(:enrollment) do
      create(
        :in_person_enrollment,
        :pending,
        selected_location_details: { name: 'FRIENDSHIP' },
        status_updated_at: Time.zone.now - 2.hours,
      )
    end

    let(:mail) do
      UserMailer.in_person_ready_to_verify(
        user,
        user.email_addresses.first,
        enrollment: enrollment,
      )
    end

    it_behaves_like 'a system email'
    it_behaves_like 'an email that respects user email locale preference'
  end

  describe '#in_person_verified' do
    let(:enrollment) do
      create(
        :in_person_enrollment,
        selected_location_details: { name: 'FRIENDSHIP' },
        status_updated_at: Time.zone.now - 2.hours,
      )
    end

    let(:mail) do
      UserMailer.in_person_verified(
        user,
        user.email_addresses.first,
        enrollment: enrollment,
      )
    end

    it_behaves_like 'a system email'
    it_behaves_like 'an email that respects user email locale preference'
  end

  describe '#in_person_failed' do
    let(:enrollment) do
      create(
        :in_person_enrollment,
        selected_location_details: { name: 'FRIENDSHIP' },
        status_updated_at: Time.zone.now - 2.hours,
      )
    end

    let(:mail) do
      UserMailer.in_person_failed(
        user,
        user.email_addresses.first,
        enrollment: enrollment,
      )
    end

    it_behaves_like 'a system email'
    it_behaves_like 'an email that respects user email locale preference'
  end

  describe '#in_person_failed_fraud' do
    let(:enrollment) do
      create(
        :in_person_enrollment,
        selected_location_details: { name: 'FRIENDSHIP' },
        status_updated_at: Time.zone.now - 2.hours,
      )
    end

    let(:mail) do
      UserMailer.in_person_failed_fraud(
        user,
        user.email_addresses.first,
        enrollment: enrollment,
      )
    end

    it_behaves_like 'a system email'
    it_behaves_like 'an email that respects user email locale preference'
  end

  describe '#in_person_completion_survey' do
    let(:mail) do
      UserMailer.in_person_completion_survey(
        user,
        email_address,
      )
    end

    it_behaves_like 'a system email'
    it_behaves_like 'an email that respects user email locale preference'

    it 'sends to the current email' do
      expect(mail.to).to eq [email_address.email]
    end

    it 'renders the subject' do
      expect(mail.subject).to eq t(
        'user_mailer.in_person_completion_survey.subject',
        app_name: APP_NAME,
      )
    end

    it 'renders the body' do
      expect(mail.html_part.body).
        to have_content(
          t(
            'user_mailer.in_person_completion_survey.body.thanks',
            app_name: APP_NAME,
          ),
        )
      expect(mail.html_part.body).
        to have_selector(
          "a[href='#{MarketingSite.security_and_privacy_practices_url}']",
        )
      expect(mail.html_part.body).
        to have_selector(
          "a[href='#{IdentityConfig.store.in_person_completion_survey_url}']",
        )
    end
  end

  def strip_tags(str)
    ActionController::Base.helpers.strip_tags(str)
  end
end
