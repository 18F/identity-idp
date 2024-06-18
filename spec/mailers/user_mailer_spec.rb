require 'rails_helper'

RSpec.describe UserMailer, type: :mailer do
  let(:user) { create(:user) }
  let(:email_address) { user.email_addresses.first }
  let(:banned_email) { 'banned_email+123abc@gmail.com' }
  let(:banned_email_address) { create(:email_address, email: banned_email, user: user) }
  let(:is_enhanced_ipp) { false }

  describe '#validate_user_and_email_address' do
    let(:mail) { UserMailer.with(user: user, email_address: email_address).signup_with_your_email }

    context 'with user and email address match' do
      it 'does not raise an error' do
        expect { mail.body }.not_to raise_error
      end
    end

    context 'with user and email address mismatch' do
      let(:user) { create(:user) }
      let(:email_address) { EmailAddress.new }

      it 'raises an error' do
        expect { mail.body }.to raise_error(UserMailer::UserEmailAddressMismatchError)
      end
    end
  end

  describe '#add_email' do
    let(:token) { SecureRandom.hex }
    let(:mail) { UserMailer.with(user: user, email_address: email_address).add_email(token) }

    it_behaves_like 'a system email'
    it_behaves_like 'an email that respects user email locale preference'

    it 'renders the add_email_confirmation_url' do
      add_email_url = add_email_confirmation_url(confirmation_token: token)

      expect(mail.html_part.body).to have_content(add_email_url)
      expect(mail.html_part.body).to_not have_content(sign_up_create_email_confirmation_url)
    end
  end

  describe '#email_deleted' do
    let(:mail) do
      UserMailer.with(user: user, email_address: email_address).email_deleted
    end

    it_behaves_like 'a system email'
    it_behaves_like 'an email that respects user email locale preference'

    it 'sends to the old email' do
      expect(mail.to).to eq [email_address.email]
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
  end

  describe '#add_email_associated_with_another_account' do
    let(:mail) do
      UserMailer.with(user: user, email_address: email_address).
        add_email_associated_with_another_account
    end

    it_behaves_like 'a system email'
    it_behaves_like 'an email that respects user email locale preference'

    it 'sends to the specified email' do
      expect(mail.to).to eq [email_address.email]
    end

    it 'renders the subject' do
      expect(mail.subject).to eq t('mailer.email_reuse_notice.subject')
    end

    it 'renders the body' do
      expect_email_body_to_have_help_and_contact_links
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
        t('user_mailer.password_changed.intro_html', app_name_html: APP_NAME),
      )
      expect(mail.html_part.body).to include(
        '/events/disavow?disavowal_token=123abc',
      )
      expect_email_body_to_have_help_and_contact_links
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
  end

  describe '#email_confirmation_instructions' do
    let(:request_id) { '1234-abcd' }
    let(:token) { 'asdf123' }

    let(:mail) do
      UserMailer.with(user: user, email_address: user.email_addresses.first).
        email_confirmation_instructions(
          token,
          request_id: request_id,
        )
    end

    it_behaves_like 'a system email'
    it_behaves_like 'an email that respects user email locale preference'
  end

  describe '#new_device_sign_in' do
    date = 'February 25, 2019 15:02'
    location = 'Washington, DC'
    device_name = 'Chrome ABC on macOS 123'
    disavowal_token = 'asdf1234'
    let(:mail) do
      UserMailer.with(user: user, email_address: email_address).new_device_sign_in(
        date: date,
        location: location,
        device_name: device_name,
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
              'user_mailer.new_device_sign_in.info',
              date: date,
              location: location,
              device_name: device_name,
              app_name: APP_NAME,
            ),
          ),
        )
      expect(mail.html_part.body).to include(
        '/events/disavow?disavowal_token=asdf1234',
      )
      expect_email_body_to_have_help_and_contact_links
    end
  end

  describe '#new_device_sign_in_before_2fa' do
    let(:event) { create(:event, event_type: :sign_in_before_2fa, user:, device: create(:device)) }
    subject(:mail) do
      UserMailer.with(user:, email_address:).new_device_sign_in_before_2fa(
        events: user.events.where(event_type: 'sign_in_before_2fa').includes(:device).to_a,
        disavowal_token: 'token',
      )
    end

    it_behaves_like 'a system email'
    it_behaves_like 'an email that respects user email locale preference'
  end

  describe '#new_device_sign_in_after_2fa' do
    let(:event) { create(:event, event_type: :sign_in_after_2fa, user:, device: create(:device)) }
    subject(:mail) do
      UserMailer.with(user:, email_address:).new_device_sign_in_after_2fa(
        events: user.events.where(event_type: 'sign_in_after_2fa').includes(:device).to_a,
        disavowal_token: 'token',
      )
    end

    it_behaves_like 'a system email'
    it_behaves_like 'an email that respects user email locale preference'
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
          app_name_html: APP_NAME,
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
    let(:interval) { '24 hours' }
    let(:account_reset_deletion_period_hours) { '24 hours' }

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
          t(
            'user_mailer.account_reset_request.intro_html', app_name: APP_NAME,
                                                            interval: interval,
                                                            waiting_period:
                                                              account_reset_deletion_period_hours
          ),
        ),
      )
    end

    it 'renders the footer' do
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
          t('user_mailer.account_reset_request.header', interval: interval),
        ),
      )
    end
  end

  describe '#account_reset_granted' do
    let(:mail) do
      UserMailer.with(user: user, email_address: email_address).
        account_reset_granted(user.account_reset_request)
    end
    let(:account_reset_deletion_period_hours) { '24 hours' }
    let(:token_expiration_interval) { '24 hours' }

    it_behaves_like 'a system email'
    it_behaves_like 'an email that respects user email locale preference'

    it 'sends to the current email' do
      expect(mail.to).to eq [email_address.email]
    end

    it 'renders the subject' do
      expect(mail.subject).to eq t(
        'user_mailer.account_reset_granted.subject', app_name: APP_NAME
      )
    end

    it 'renders the body' do
      expect(mail.html_part.body).to \
        have_content(
          strip_tags(
            t(
              'user_mailer.account_reset_granted.intro_html', app_name: APP_NAME,
                                                              waiting_period:
                                                              account_reset_deletion_period_hours
            ),
          ),
        )
    end

    it 'renders the footer' do
      expect(mail.html_part.body).to \
        have_content(
          strip_tags(
            t(
              'user_mailer.email_confirmation_instructions.footer',
              confirmation_period: token_expiration_interval,
            ),
          ),
        )
    end
  end

  describe '#account_reset_complete' do
    let(:mail) do
      UserMailer.with(user: user, email_address: email_address).
        account_reset_complete
    end

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
          strip_tags(t('user_mailer.account_reset_complete.intro_html', app_name_html: APP_NAME)),
        )
    end
  end

  describe '#account_delete_submitted' do
    let(:mail) do
      UserMailer.with(user: user, email_address: email_address).
        account_delete_submitted
    end

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
          strip_tags(t('user_mailer.account_reset_complete.intro_html', app_name_html: APP_NAME)),
        )
    end
  end

  describe '#account_reset_cancel' do
    let(:mail) do
      UserMailer.with(user: user, email_address: email_address).
        account_reset_cancel
    end

    it_behaves_like 'a system email'
    it_behaves_like 'an email that respects user email locale preference'

    it 'sends to the current email' do
      expect(mail.to).to eq [email_address.email]
    end

    it 'renders the subject' do
      expect(mail.subject).to eq t('user_mailer.account_reset_cancel.subject')
    end

    it 'renders the body' do
      expect(mail.html_part.body).
        to have_content(
          strip_tags(t('user_mailer.account_reset_cancel.intro_html', app_name_html: APP_NAME)),
        )
    end
  end

  describe '#please_reset_password' do
    let(:mail) { UserMailer.with(user: user, email_address: email_address).please_reset_password }

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

    it 'logs email metadata to analytics' do
      analytics = FakeAnalytics.new
      allow(Analytics).to receive(:new).and_return(analytics)
      allow(analytics).to receive(:track_event)

      user = create(:user)
      email_address = user.email_addresses.first
      mail = UserMailer.with(user: user, email_address: email_address).please_reset_password
      mail.deliver_now

      expect(analytics).
        to have_received(:track_event).with(
          'Email Sent',
          action: 'please_reset_password', ses_message_id: nil, email_address_id: email_address.id,
        )
    end
  end

  describe '#verify_by_mail_letter_requested' do
    let(:mail) do
      UserMailer.with(user: user, email_address: email_address).verify_by_mail_letter_requested
    end

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
        to have_content(strip_tags(t('user_mailer.letter_reminder.info_html', link_html: APP_NAME)))
    end
  end

  describe '#account_verified' do
    disavowal_token = 'i_am_disavowal_token'
    let(:sp_name) { '' }
    let(:date_time) { Time.zone.now }
    let(:mail) do
      UserMailer.with(user: user, email_address: email_address).
        account_verified(
          date_time: date_time, sp_name: sp_name,
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

    it 'links to the forgot password page' do
      expect(mail.html_part.body).to have_selector("a[href='#{new_user_password_url}']")
    end
  end

  context 'in person emails' do
    let(:current_address_matches_id) { false }
    let!(:enrollment) do
      create(
        :in_person_enrollment,
        :pending,
        selected_location_details: { name: 'FRIENDSHIP' },
        status_updated_at: Time.zone.now - 2.hours,
        current_address_matches_id: current_address_matches_id,
      )
    end

    describe '#in_person_ready_to_verify' do
      let(:mail) do
        UserMailer.with(user: user, email_address: email_address).in_person_ready_to_verify(
          enrollment: enrollment,
          is_enhanced_ipp:,
        )
      end

      it_behaves_like 'a system email'
      it_behaves_like 'an email that respects user email locale preference'

      context 'Outage message' do
        let(:formatted_date) { 'Tuesday, October 31' }
        let(:in_person_outage_emailed_by_date) { 'November 1, 2023' }
        let(:in_person_outage_expected_update_date) { 'October 31, 2023' }

        it 'renders a warning when the flag is enabled' do
          allow(IdentityConfig.store).to receive(:in_person_outage_message_enabled).
            and_return(true)
          allow(IdentityConfig.store).to receive(:in_person_outage_emailed_by_date).
            and_return(in_person_outage_emailed_by_date)
          allow(IdentityConfig.store).to receive(:in_person_outage_expected_update_date).
            and_return(in_person_outage_expected_update_date)

          expect(mail.html_part.body).
            to have_content(
              t(
                'idv.failure.exceptions.in_person_outage_error_message.ready_to_verify.title',
                date: formatted_date,
              ),
            )
        end

        it 'does not render a warning when outage dates are not included' do
          allow(IdentityConfig.store).to receive(:in_person_outage_message_enabled).
            and_return(true)
          allow(IdentityConfig.store).to receive(:in_person_outage_emailed_by_date).
            and_return('')
          allow(IdentityConfig.store).to receive(:in_person_outage_expected_update_date).
            and_return('')

          expect(mail.html_part.body).to_not have_content(
            t(
              'idv.failure.exceptions.in_person_outage_error_message.ready_to_verify.title',
              date: formatted_date,
            ),
          )
        end

        it 'does not render a warning when the flag is disabled' do
          allow(IdentityConfig.store).to receive(:in_person_outage_message_enabled).
            and_return(false)

          expect(mail.html_part.body).
            to_not have_content(
              t('idv.failure.exceptions.in_person_outage_error_message.ready_to_verify.title'),
            )
        end
      end

      context 'For In-Person Proofing (IPP)' do
        context 'template displays modified content' do
          it 'conditionally renders content in the what to expect section applicable to IPP' do
            aggregate_failures do
              [
                t('in_person_proofing.headings.barcode'),
                t('in_person_proofing.process.state_id.heading'),
                t('in_person_proofing.process.state_id.info'),
              ].each do |copy|
                Array(copy).each do |part|
                  expect(mail.html_part.body).to have_content(part)
                end
              end
            end
          end
        end

        it 'renders Questions? and Learn more link only once' do
          expect(mail.html_part.body).to have_content(
            t('in_person_proofing.body.barcode.questions'),
          ).once
          expect(mail.html_part.body).to have_link(
            t('in_person_proofing.body.barcode.learn_more'),
            href: MarketingSite.help_center_article_url(
              category: 'verify-your-identity',
              article: 'verify-your-identity-in-person',
            ),
          ).once
        end

        it 'template does not display Enhanced In-Person Proofing specific content' do
          aggregate_failures do
            [
              t('in_person_proofing.headings.barcode_eipp'),
              t('in_person_proofing.process.state_id.heading_eipp'),
              t('in_person_proofing.process.state_id.info_eipp'),
              t('in_person_proofing.headings.barcode_what_to_bring'),
              t('in_person_proofing.body.barcode.what_to_bring'),
              t('in_person_proofing.process.eipp_bring_id.heading'),
              t('in_person_proofing.process.eipp_bring_id.info'),
              t('in_person_proofing.process.eipp_what_to_bring.heading'),
              t('in_person_proofing.process.eipp_what_to_bring.info'),
              t('in_person_proofing.process.eipp_state_id_passport.heading'),
              t('in_person_proofing.process.eipp_state_id_passport.info'),
              t('in_person_proofing.process.eipp_state_id_military_id.heading'),
              t('in_person_proofing.process.eipp_state_id_military_id.info'),
              t('in_person_proofing.process.eipp_state_id_supporting_docs.heading'),
              t('in_person_proofing.process.eipp_state_id_supporting_docs.info'),
            ].each do |copy|
              Array(copy).each do |part|
                expect(mail.html_part.body).to_not have_content(part)
              end
            end
          end

          t('in_person_proofing.process.eipp_state_id_supporting_docs.info_list').each do |item|
            expect(mail.html_part.body).to_not have_content(strip_tags(item))
          end
        end
      end

      context 'For Enhanced In-Person Proofing (Enhanced IPP)' do
        let(:is_enhanced_ipp) { true }
        let(:mail) do
          UserMailer.with(user: user, email_address: email_address).in_person_ready_to_verify(
            enrollment: enrollment,
            is_enhanced_ipp:,
          )
        end

        context 'template displays modified content' do
          it 'conditionally renders content in the what to expect section
            applicable to Enhanced In-Person Proofing (Enhanced IPP)' do
            aggregate_failures do
              [
                t('in_person_proofing.headings.barcode_eipp'),
                t('in_person_proofing.process.state_id.heading_eipp'),
                t('in_person_proofing.process.state_id.info_eipp'),
              ].each do |copy|
                Array(copy).each do |part|
                  expect(mail.html_part.body).to have_content(part)
                end
              end
            end
          end
        end

        it 'renders Questions? and Learn more link only once' do
          expect(mail.html_part.body).to have_content(
            t('in_person_proofing.body.barcode.questions'),
          ).once
          expect(mail.html_part.body).to have_link(
            t('in_person_proofing.body.barcode.learn_more'),
            href: MarketingSite.help_center_article_url(
              category: 'verify-your-identity',
              article: 'verify-your-identity-in-person',
            ),
          ).once
        end

        context 'template displays additional Enhanced In-Person Proofing specific content' do
          it 'renders What to bring section' do
            aggregate_failures do
              [
                t('in_person_proofing.headings.barcode_what_to_bring'),
                t('in_person_proofing.body.barcode.what_to_bring'),
              ].each do |copy|
                Array(copy).each do |part|
                  expect(mail.html_part.body).to have_content(part)
                end
              end
            end
          end

          it 'renders Option 1 content' do
            aggregate_failures do
              [
                t('in_person_proofing.process.eipp_bring_id.heading'),
                t('in_person_proofing.process.eipp_bring_id.info'),
              ].each do |copy|
                Array(copy).each do |part|
                  expect(mail.html_part.body).to have_content(part)
                end
              end
            end
          end

          it 'renders Option 2 content' do
            aggregate_failures do
              [
                t('in_person_proofing.process.eipp_what_to_bring.heading'),
                t('in_person_proofing.process.eipp_what_to_bring.info'),
                t('in_person_proofing.process.eipp_state_id_passport.heading'),
                t('in_person_proofing.process.eipp_state_id_passport.info'),
                t('in_person_proofing.process.eipp_state_id_military_id.heading'),
                t('in_person_proofing.process.eipp_state_id_military_id.info'),
                t('in_person_proofing.process.eipp_state_id_supporting_docs.heading'),
                t('in_person_proofing.process.eipp_state_id_supporting_docs.info'),
              ].each do |copy|
                Array(copy).each do |part|
                  expect(mail.html_part.body).to have_content(part)
                end

                t('in_person_proofing.process.eipp_state_id_supporting_docs.info_list').
                  each do |item|
                  expect(mail.html_part.body).to have_content(strip_tags(item))
                end
              end
            end
          end
        end
      end
    end

    describe '#in_person_ready_to_verify_reminder' do
      let(:mail) do
        UserMailer.with(
          user: user,
          email_address: email_address,
        ).in_person_ready_to_verify_reminder(
          enrollment: enrollment,
        )
      end

      it_behaves_like 'a system email'
      it_behaves_like 'an email that respects user email locale preference'

      it 'renders the body' do
        expect(mail.html_part.body).
          to have_content(
            t('in_person_proofing.process.state_id.heading'),
          )
      end
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
        UserMailer.with(user: user, email_address: email_address).in_person_verified(
          enrollment: enrollment,
        )
      end

      it_behaves_like 'a system email'
      it_behaves_like 'an email that respects user email locale preference'
    end

    describe '#in_person_failed' do
      let!(:enrollment) do
        create(
          :in_person_enrollment,
          selected_location_details: { name: 'FRIENDSHIP' },
          status_updated_at: Time.zone.now - 2.hours,
          current_address_matches_id: current_address_matches_id,
        )
      end

      let(:mail) do
        UserMailer.with(user: user, email_address: email_address).in_person_failed(
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
        UserMailer.with(user: user, email_address: email_address).in_person_failed_fraud(
          enrollment: enrollment,
        )
      end

      it_behaves_like 'a system email'
      it_behaves_like 'an email that respects user email locale preference'
    end

    describe '#in_person_please_call' do
      let(:mail) do
        UserMailer.with(user: user, email_address: email_address).in_person_please_call(
          enrollment: enrollment,
        )
      end

      it_behaves_like 'a system email'
      it_behaves_like 'an email that respects user email locale preference'
    end

    describe '#in_person_completion_survey' do
      let(:mail) do
        UserMailer.with(user: user, email_address: email_address).in_person_completion_survey
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
  end

  describe '#suspended_reset_password' do
    let(:mail) do
      UserMailer.with(user: user, email_address: email_address).
        suspended_reset_password
    end

    it_behaves_like 'a system email'
    it_behaves_like 'an email that respects user email locale preference'

    it 'sends to the specified email' do
      expect(mail.to).to eq [email_address.email]
    end

    it 'renders the subject' do
      expect(mail.subject).to eq t('user_mailer.suspended_reset_password.subject')
    end

    it 'renders the body' do
      expect(mail.html_part.body).
        to have_content(
          t(
            'user_mailer.suspended_reset_password.message',
            support_code: IdentityConfig.store.account_suspended_support_code,
            contact_number: IdentityConfig.store.idv_contact_phone_number,
          ),
        )
    end
  end

  describe '#suspended_create_account' do
    let(:mail) do
      UserMailer.with(user: user, email_address: email_address).suspended_create_account
    end

    it_behaves_like 'a system email'
    it_behaves_like 'an email that respects user email locale preference'

    it 'sends to the specified email' do
      expect(mail.to).to eq [email_address.email]
    end

    it 'renders the subject' do
      expect(mail.subject).to eq t('user_mailer.suspended_create_account.subject')
    end

    it 'renders the body' do
      expect(mail.html_part.body).
        to have_content(
          t(
            'user_mailer.suspended_create_account.message',
            app_name: APP_NAME,
            support_code: IdentityConfig.store.account_suspended_support_code,
            contact_number: IdentityConfig.store.idv_contact_phone_number,
          ),
        )
    end
  end

  describe '#deliver_later' do
    it 'does not queue email if it potentially contains sensitive value' do
      user = create(:user)
      mailer = UserMailer.with(
        user: user,
        email_address: user.email_addresses.first,
      ).add_email(Idp::Constants::MOCK_IDV_APPLICANT[:last_name])
      expect { mailer.deliver_later }.to raise_error(
        MailerSensitiveInformationChecker::SensitiveValueError,
      )
    end

    it 'does not queue email if it potentially contains sensitive keys' do
      user = create(:user)
      mailer = UserMailer.with(user: user, email_address: user.email_addresses.first).add_email(
        {
          first_name: nil,
        },
      )
      expect { mailer.deliver_later }.to raise_error(
        MailerSensitiveInformationChecker::SensitiveKeyError,
      )
    end
  end

  describe '#verify_by_mail_reminder' do
    let(:date_letter_was_sent) { Date.new(1969, 7, 20) }

    let(:user) do
      user = create(:user, :with_pending_gpo_profile)
      user.pending_profile.update(gpo_verification_pending_at: date_letter_was_sent)
      user
    end

    let(:mail) do
      UserMailer.with(user: user, email_address: email_address).verify_by_mail_reminder
    end

    it_behaves_like 'a system email'
    it_behaves_like 'an email that respects user email locale preference'

    it 'sends to the specified email' do
      expect(mail.to).to eq [email_address.email]
    end

    it 'renders the subject' do
      expect(mail.subject).to eq t('user_mailer.letter_reminder_14_days.subject')
    end

    it 'renders the body' do
      expected_help_link = ActionController::Base.helpers.link_to(
        t('idv.troubleshooting.options.learn_more_verify_by_mail'),
        help_center_redirect_url(
          category: 'verify-your-identity',
          article: 'verify-your-address-by-mail',
          flow: :idv,
          step: :gpo_send_letter,
        ),
        { style: "text-decoration: 'underline'" },
      )

      expected_body = strip_tags(
        t(
          'user_mailer.letter_reminder_14_days.body_html',
          date_letter_was_sent: date_letter_was_sent.strftime(t('time.formats.event_date')),
          app_name: APP_NAME,
          help_link: expected_help_link,
        ),
      )

      expect(mail.html_part.body).to have_content(expected_body)
    end

    it 'renders the finish link' do
      expect(mail.html_part.body).to have_link(
        t('user_mailer.letter_reminder_14_days.finish'),
        href: idv_verify_by_mail_enter_code_url,
      )
    end

    it 'renders the did not get it link' do
      expect(mail.html_part.body).to have_link(
        t('user_mailer.letter_reminder_14_days.sign_in_and_request_another_letter'),
        href: idv_verify_by_mail_enter_code_url(did_not_receive_letter: 1),
      )
    end

    it 'renders the help link' do
      expect(mail.html_part.body).to have_link(
        t('idv.troubleshooting.options.learn_more_verify_by_mail'),
        href: help_center_redirect_url(
          category: 'verify-your-identity',
          article: 'verify-your-address-by-mail',
          flow: :idv,
          step: :gpo_send_letter,
        ),
      )
    end
  end

  describe '#suspension_confirmed' do
    let(:mail) do
      UserMailer.with(user: user, email_address: email_address).suspension_confirmed
    end

    it_behaves_like 'a system email'
    it_behaves_like 'an email that respects user email locale preference'

    it 'does not link to the help center' do
      expect(mail.html_part.body).to_not include(MarketingSite.nice_help_url)
    end

    context 'in another language' do
      let(:user) { build(:user, email_language: :es) }

      it 'translates the footer help text correctly' do
        expect(mail.html_part.body).
          to include(t('user_mailer.suspension_confirmed.contact_agency', locale: :es))
        expect(mail.html_part.body).
          to_not include(t('user_mailer.suspension_confirmed.contact_agency', locale: :en))
      end
    end
  end

  describe '#account_reinstated' do
    let(:mail) do
      UserMailer.with(user: user, email_address: email_address).account_reinstated
    end

    it_behaves_like 'a system email'
    it_behaves_like 'an email that respects user email locale preference'
  end
end
