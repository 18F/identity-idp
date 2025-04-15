# frozen_string_literal: true

# UserMailer handles all email sending to the User class. It expects to be called using `with`
# that receives a `user` and `email_address`. This pattern is preferred as the User and
# EmailAddress database records are needed across any email being sent.
#
# Arguments sent to UserMailer must not include personally-identifiable information (PII).
# This includes email addresses. All arguments to UserMailer are stored in the database when the
# email is being sent asynchronously by ActiveJob and we must not put PII in the database in
# plaintext.
#
# Example:
#
#   UserMailer.with(user: user, email_address: email_address).
#     reset_password_instructions(token: token)
#
class UserMailer < ActionMailer::Base
  include Mailable
  include LocaleHelper
  include AccountResetConcern
  include ActionView::Helpers::DateHelper

  class UserEmailAddressMismatchError < StandardError; end

  before_action :validate_user_and_email_address
  before_action :attach_images
  after_action :add_metadata

  default(
    from: email_with_name(
      IdentityConfig.store.email_from,
      IdentityConfig.store.email_from_display_name,
    ),
    reply_to: email_with_name(
      IdentityConfig.store.email_from,
      IdentityConfig.store.email_from_display_name,
    ),
  )

  layout 'mailer'

  def email_confirmation_instructions(token, request_id:)
    with_user_locale(user) do
      presenter = ConfirmationEmailPresenter.new(user, view_context)
      @first_sentence = presenter.first_sentence
      @confirmation_period = presenter.confirmation_period
      @request_id = request_id
      @locale = locale_url_param
      @token = token
      mail(
        to: email_address.email,
        subject: t('user_mailer.email_confirmation_instructions.subject'),
      )
    end
  end

  def signup_with_your_email(request_id:)
    with_user_locale(user) do
      @root_url = root_url(locale: locale_url_param, request_id: request_id)
      mail(to: email_address.email, subject: t('mailer.email_reuse_notice.subject'))
    end
  end

  def reset_password_instructions(token:, request_id:)
    with_user_locale(user) do
      @locale = locale_url_param
      @token = token
      @request_id = request_id
      @gpo_verification_pending_profile = user.gpo_verification_pending_profile?
      @in_person_verification_pending_profile = user.in_person_pending_profile?
      @hide_title = @gpo_verification_pending_profile || @in_person_verification_pending_profile
      mail(to: email_address.email, subject: t('user_mailer.reset_password_instructions.subject'))
    end
  end

  def password_changed(disavowal_token:)
    with_user_locale(user) do
      @disavowal_token = disavowal_token
      mail(to: email_address.email, subject: t('devise.mailer.password_updated.subject'))
    end
  end

  def phone_added(disavowal_token:)
    with_user_locale(user) do
      @disavowal_token = disavowal_token
      mail(to: email_address.email, subject: t('user_mailer.phone_added.subject'))
    end
  end

  def personal_key_sign_in(disavowal_token:)
    with_user_locale(user) do
      @disavowal_token = disavowal_token
      mail(to: email_address.email, subject: t('user_mailer.personal_key_sign_in.subject'))
    end
  end

  # @param [Array<Hash>] events Array of sign-in Event records (event types "sign_in_before_2fa",
  # "sign_in_after_2fa", "sign_in_unsuccessful_2fa")
  # @param [String] disavowal_token Token to generate URL for disavowing event
  def new_device_sign_in_after_2fa(events:, disavowal_token:)
    with_user_locale(user) do
      @events = events
      @disavowal_token = disavowal_token

      mail(
        to: email_address.email,
        subject: t('user_mailer.new_device_sign_in_after_2fa.subject', app_name: APP_NAME),
      )
    end
  end

  # @param [Array<Hash>] events Array of sign-in Event records (event types "sign_in_before_2fa",
  # "sign_in_after_2fa", "sign_in_unsuccessful_2fa")
  # @param [String] disavowal_token Token to generate URL for disavowing event
  def new_device_sign_in_before_2fa(events:, disavowal_token:)
    with_user_locale(user) do
      @events = events
      @disavowal_token = disavowal_token
      @failed_times = events.count { |event| event.event_type == 'sign_in_unsuccessful_2fa' }

      mail(
        to: email_address.email,
        subject: t('user_mailer.new_device_sign_in_before_2fa.subject', app_name: APP_NAME),
      )
    end
  end

  def personal_key_regenerated
    with_user_locale(user) do
      mail(to: email_address.email, subject: t('user_mailer.personal_key_regenerated.subject'))
    end
  end

  def account_reset_request(account_reset)
    with_user_locale(user) do
      @token = account_reset&.request_token
      @account_reset_deletion_period_interval = account_reset_deletion_period_interval(user)
      @header = t(
        'user_mailer.account_reset_request.header',
        interval: @account_reset_deletion_period_interval,
      )
      mail(
        to: email_address.email,
        subject: t('user_mailer.account_reset_request.subject', app_name: APP_NAME),
      )
    end
  end

  def account_reset_granted(account_reset)
    with_user_locale(user) do
      @token = account_reset&.request_token
      @granted_token = account_reset&.granted_token
      @account_reset_deletion_period_interval = account_reset_deletion_period_interval(user)
      @account_reset_token_valid_period = account_reset_token_valid_period
      mail(
        to: email_address.email,
        subject: t('user_mailer.account_reset_granted.subject', app_name: APP_NAME),
      )
    end
  end

  def account_reset_complete
    with_user_locale(user) do
      mail(to: email_address.email, subject: t('user_mailer.account_reset_complete.subject'))
    end
  end

  def account_delete_submitted
    with_user_locale(user) do
      mail(to: email_address.email, subject: t('user_mailer.account_reset_complete.subject'))
    end
  end

  def account_reset_cancel
    with_user_locale(user) do
      mail(to: email_address.email, subject: t('user_mailer.account_reset_cancel.subject'))
    end
  end

  def please_reset_password
    with_user_locale(user) do
      mail(
        to: email_address.email,
        subject: t('user_mailer.please_reset_password.subject', app_name: APP_NAME),
      )
    end
  end

  def verify_by_mail_letter_requested
    with_user_locale(user) do
      @hide_title = true
      @presenter = Idv::ByMail::LetterRequestedEmailPresenter.new(
        current_user: user,
        url_options:,
      )
      mail(
        to: email_address.email,
        subject: t('user_mailer.verify_by_mail_letter_requested.subject'),
      )
    end
  end

  def add_email(token:, request_id:, from_select_email_flow: nil)
    with_user_locale(user) do
      presenter = ConfirmationEmailPresenter.new(user, view_context)
      @first_sentence = presenter.first_sentence
      @confirmation_period = presenter.confirmation_period
      @add_email_url = add_email_confirmation_url(
        confirmation_token: token,
        from_select_email_flow:,
        locale: locale_url_param,
        request_id:,
      )
      mail(to: email_address.email, subject: t('user_mailer.add_email.subject'))
    end
  end

  def email_added
    with_user_locale(user) do
      mail(to: email_address.email, subject: t('user_mailer.email_added.subject'))
    end
  end

  def email_deleted
    with_user_locale(user) do
      mail(to: email_address.email, subject: t('user_mailer.email_deleted.subject'))
    end
  end

  def add_email_associated_with_another_account
    with_user_locale(user) do
      @root_url = root_url(locale: locale_url_param)
      mail(to: email_address.email, subject: t('mailer.email_reuse_notice.subject'))
    end
  end

  def account_verified(profile:)
    attachments.inline['verified.png'] =
      Rails.root.join('app/assets/images/email/user-signup-ial2.png').read
    with_user_locale(user) do
      @presenter = Idv::AccountVerifiedEmailPresenter.new(profile:, url_options:)
      @hide_title = true
      @date = I18n.l(profile.verified_at, format: :event_date)
      mail(
        to: email_address.email,
        subject: t('user_mailer.account_verified.subject', app_name: APP_NAME),
      )
    end
  end

  def idv_please_call(**)
    attachments.inline['phone_icon.png'] =
      Rails.root.join('app/assets/images/email/phone_icon.png').read

    with_user_locale(user) do
      @hide_title = true

      mail(
        to: email_address.email,
        subject: t('user_mailer.idv_please_call.subject', app_name: APP_NAME),
        template_name: 'idv_please_call',
      )
    end
  end

  def in_person_completion_survey
    with_user_locale(user) do
      @header = t('user_mailer.in_person_completion_survey.header')
      @privacy_url = MarketingSite.security_and_privacy_practices_url
      if locale == :en
        @survey_url = IdentityConfig.store.in_person_opt_in_available_completion_survey_url
      else
        @survey_url = IdentityConfig.store.in_person_completion_survey_url
      end

      mail(
        to: email_address.email,
        subject: t('user_mailer.in_person_completion_survey.subject', app_name: APP_NAME),
      )
    end
  end

  def in_person_deadline_passed(enrollment:, visited_location_name: nil)
    with_user_locale(user) do
      @header = t('user_mailer.in_person_deadline_passed.header')
      @presenter = Idv::InPerson::VerificationResultsEmailPresenter.new(
        enrollment: enrollment,
        url_options: url_options,
        visited_location_name: visited_location_name,
      )
      mail(
        to: email_address.email,
        subject: t('user_mailer.in_person_deadline_passed.subject', app_name: APP_NAME),
      )
    end
  end

  def in_person_ready_to_verify(enrollment:)
    attachments.inline['barcode.png'] = BarcodeOutputter.new(
      code: enrollment.enrollment_code,
    ).image_data

    with_user_locale(user) do
      @hide_title = IdentityConfig.store.in_person_outage_message_enabled &&
                    IdentityConfig.store.in_person_outage_emailed_by_date.present? &&
                    IdentityConfig.store.in_person_outage_expected_update_date.present?
      @presenter = Idv::InPerson::ReadyToVerifyPresenter.new(
        enrollment: enrollment,
        barcode_image_url: attachments['barcode.png'].url,
      )
      @header = @presenter.enhanced_ipp? ?
      t('in_person_proofing.headings.barcode_eipp') : t('in_person_proofing.headings.barcode')

      if enrollment&.service_provider&.logo_is_email_compatible?
        @logo_url = enrollment.service_provider.logo_url
      else
        @logo_url = nil
      end
      @sp_name = @presenter.sp_name

      mail(
        to: email_address.email,
        subject: t('user_mailer.in_person_ready_to_verify.subject', app_name: APP_NAME),
      )
    end
  end

  def in_person_ready_to_verify_reminder(enrollment:)
    attachments.inline['barcode.png'] = BarcodeOutputter.new(
      code: enrollment.enrollment_code,
    ).image_data

    with_user_locale(user) do
      @presenter = Idv::InPerson::ReadyToVerifyPresenter.new(
        enrollment: enrollment,
        barcode_image_url: attachments['barcode.png'].url,
      )
      if enrollment&.service_provider&.logo_is_email_compatible?
        @logo_url = enrollment.service_provider.logo_url
      else
        @logo_url = nil
      end
      @sp_name = @presenter.sp_name
      @header = t(
        'user_mailer.in_person_ready_to_verify_reminder.heading',
        count: @presenter.days_remaining,
      )

      mail(
        to: email_address.email,
        subject: t(
          'user_mailer.in_person_ready_to_verify_reminder.subject',
          count: @presenter.days_remaining,
        ),
      )
    end
  end

  def in_person_verified(enrollment:, visited_location_name: nil)
    with_user_locale(user) do
      @hide_title = true
      @presenter = Idv::InPerson::VerificationResultsEmailPresenter.new(
        enrollment: enrollment,
        url_options: url_options,
        visited_location_name: visited_location_name,
      )
      mail(
        to: email_address.email,
        subject: t('user_mailer.in_person_verified.subject', app_name: APP_NAME),
      )
    end
  end

  def in_person_failed(enrollment:, visited_location_name: nil)
    with_user_locale(user) do
      @presenter = Idv::InPerson::VerificationResultsEmailPresenter.new(
        enrollment: enrollment,
        url_options: url_options,
        visited_location_name: visited_location_name,
      )
      mail(
        to: email_address.email,
        subject: t('user_mailer.in_person_failed.subject', app_name: APP_NAME),
      )
    end
  end

  def in_person_failed_fraud(enrollment:, visited_location_name: nil)
    with_user_locale(user) do
      @presenter = Idv::InPerson::VerificationResultsEmailPresenter.new(
        enrollment: enrollment,
        url_options: url_options,
        visited_location_name: visited_location_name,
      )
      mail(
        to: email_address.email,
        subject: t('user_mailer.in_person_failed_suspected_fraud.subject'),
      )
    end
  end

  def account_rejected
    with_user_locale(user) do
      mail(
        to: email_address.email,
        subject: t('user_mailer.account_rejected.subject'),
      )
    end
  end

  def suspended_create_account
    with_user_locale(user) do
      mail(to: email_address.email, subject: t('user_mailer.suspended_create_account.subject'))
    end
  end

  def suspended_reset_password
    with_user_locale(user) do
      mail(to: email_address.email, subject: t('user_mailer.suspended_reset_password.subject'))
    end
  end

  def verify_by_mail_reminder
    with_user_locale(user) do
      @gpo_verification_pending_at = I18n.l(
        user.gpo_verification_pending_profile.gpo_verification_pending_at,
        format: :event_date,
      )
      mail(to: email_address.email, subject: t('user_mailer.letter_reminder_14_days.subject'))
    end
  end

  def suspension_confirmed
    with_user_locale(user) do
      @help_text = t('user_mailer.suspension_confirmed.contact_agency')

      mail(to: email_address.email, subject: t('user_mailer.suspension_confirmed.subject'))
    end
  end

  def account_reinstated
    with_user_locale(user) do
      mail(to: email_address.email, subject: t('user_mailer.account_reinstated.subject'))
    end
  end

  private

  attr_reader :user, :email_address

  def validate_user_and_email_address
    @user = params.fetch(:user)
    @email_address = params.fetch(:email_address)
    if @user.id != @email_address.user_id
      raise UserEmailAddressMismatchError.new(
        "User ID #{@user.id} does not match EmailAddress ID #{@email_address.id}",
      )
    end
  end

  def add_metadata
    message.instance_variable_set(
      :@_metadata, {
        user: user, email_address: email_address, action: action_name
      }
    )
  end

  def account_reset_token_valid_period
    current_time = Time.zone.now

    distance_of_time_in_words(
      current_time,
      current_time + IdentityConfig.store.account_reset_token_valid_for_days.days,
      true,
      accumulate_on: :hours,
    )
  end
end
