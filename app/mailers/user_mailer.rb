# UserMailer handles all email sending to the User class. It expects to be called using `with`
# that receives a `user` and `email_address`. This pattern is preferred as the User and
# EmailAddress database records are needed across any email being sent.
#
# Arguments sent to UserMailer must not include personally-identifiable information (PII).
# This includes email addresses. All arguments to UserMailer are stored in the database when the
# email is being sent asynchronusly by ActiveJob and we must not put PII in the database in
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

  class UserEmailAddressMismatchError < StandardError; end

  attr_reader :user, :email_address

  before_action :validate_user_and_email_address
  before_action :attach_images
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

  def validate_user_and_email_address
    @user = params.fetch(:user)
    @email_address = params.fetch(:email_address)
    if @user.id != @email_address.user_id
      raise UserEmailAddressMisMatchError.new(
        "User ID #{@user.id} does not match EmailAddress ID #{@email_address.id}",
      )
    end
  end

  def email_confirmation_instructions(token, request_id:, instructions:)
    with_user_locale(user) do
      presenter = ConfirmationEmailPresenter.new(user, view_context)
      @first_sentence = instructions || presenter.first_sentence
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

  def unconfirmed_email_instructions(token, request_id:, instructions:)
    with_user_locale(user) do
      presenter = ConfirmationEmailPresenter.new(user, view_context)
      @first_sentence = instructions || presenter.first_sentence
      @confirmation_period = presenter.confirmation_period
      @request_id = request_id
      @locale = locale_url_param
      @token = token
      mail(
        to: email_address.email,
        subject: t('user_mailer.email_confirmation_instructions.email_not_found'),
      )
    end
  end

  def signup_with_your_email
    with_user_locale(user) do
      @root_url = root_url(locale: locale_url_param)
      mail(to: email_address.email, subject: t('mailer.email_reuse_notice.subject'))
    end
  end

  def reset_password_instructions(token:)
    with_user_locale(user) do
      @locale = locale_url_param
      @token = token
      @pending_profile_requires_verification = user.decorate.pending_profile_requires_verification?
      @hide_title = @pending_profile_requires_verification
      mail(to: email_address, subject: t('user_mailer.reset_password_instructions.subject'))
    end
  end

  def password_changed(disavowal_token:)
    return unless email_should_receive_nonessential_notifications?(email_address.email)

    with_user_locale(user) do
      @disavowal_token = disavowal_token
      mail(to: email_address.email, subject: t('devise.mailer.password_updated.subject'))
    end
  end

  def phone_added(disavowal_token:)
    return unless email_should_receive_nonessential_notifications?(email_address.email)

    with_user_locale(user) do
      @disavowal_token = disavowal_token
      mail(to: email_address.email, subject: t('user_mailer.phone_added.subject'))
    end
  end

  def personal_key_sign_in(disavowal_token:)
    return unless email_should_receive_nonessential_notifications?(email_address.email)

    with_user_locale(user) do
      @disavowal_token = disavowal_token
      mail(to: email_address.email, subject: t('user_mailer.personal_key_sign_in.subject'))
    end
  end

  def new_device_sign_in(date:, location:, disavowal_token:)
    return unless email_should_receive_nonessential_notifications?(email_address.email)

    with_user_locale(user) do
      @login_date = date
      @login_location = location
      @disavowal_token = disavowal_token
      mail(
        to: email_address.email,
        subject: t('user_mailer.new_device_sign_in.subject', app_name: APP_NAME),
      )
    end
  end

  def personal_key_regenerated
    return unless email_should_receive_nonessential_notifications?(email_address.email)

    with_user_locale(user) do
      mail(to: email_address.email, subject: t('user_mailer.personal_key_regenerated.subject'))
    end
  end

  def account_reset_request(account_reset)
    with_user_locale(user) do
      @token = account_reset&.request_token
      @header = t('user_mailer.account_reset_request.header')
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

  def doc_auth_desktop_link_to_sp(application, link)
    with_user_locale(user) do
      @link = link
      @application = application
      mail(to: email_address.email, subject: t('user_mailer.doc_auth_link.subject'))
    end
  end

  def letter_reminder
    return unless email_should_receive_nonessential_notifications?(email_address.email)

    with_user_locale(user) do
      mail(to: email_address.email, subject: t('user_mailer.letter_reminder.subject'))
    end
  end

  def add_email(token)
    with_user_locale(user) do
      presenter = ConfirmationEmailPresenter.new(user, view_context)
      @first_sentence = presenter.first_sentence
      @confirmation_period = presenter.confirmation_period
      @add_email_url = add_email_confirmation_url(
        confirmation_token: token,
        locale: locale_url_param,
      )
      mail(to: email_address.email, subject: t('user_mailer.add_email.subject'))
    end
  end

  def email_added
    return unless email_should_receive_nonessential_notifications?(email_address.email)

    with_user_locale(user) do
      mail(to: email_address.email, subject: t('user_mailer.email_added.subject'))
    end
  end

  def email_deleted
    return unless email_should_receive_nonessential_notifications?(email_address.email)

    with_user_locale(user) do
      mail(to: email_address.email, subject: t('user_mailer.email_deleted.subject'))
    end
  end

  def add_email_associated_with_another_account(email)
    @root_url = root_url(locale: locale_url_param)
    mail(to: email, subject: t('mailer.email_reuse_notice.subject'))
  end

  def account_verified(date_time:, sp_name:, disavowal_token:)
    return unless email_should_receive_nonessential_notifications?(email_address.email)

    with_user_locale(user) do
      @date = I18n.l(date_time, format: :event_date)
      @sp_name = sp_name
      @disavowal_token = disavowal_token
      mail(
        to: email_address.email,
        subject: t('user_mailer.account_verified.subject', sp_name: @sp_name),
      )
    end
  end

  def in_person_completion_survey
    with_user_locale(user) do
      @header = t('user_mailer.in_person_completion_survey.header')
      @privacy_url = MarketingSite.security_and_privacy_practices_url
      @survey_url = IdentityConfig.store.in_person_completion_survey_url
      mail(
        to: email_address.email,
        subject: t('user_mailer.in_person_completion_survey.subject', app_name: APP_NAME),
      )
    end
  end

  def in_person_ready_to_verify(user, email_address, enrollment:)
    attachments.inline['barcode.png'] = BarcodeOutputter.new(
      code: enrollment.enrollment_code,
    ).image_data

    with_user_locale(user) do
      @header = t('in_person_proofing.headings.barcode')
      @presenter = Idv::InPerson::ReadyToVerifyPresenter.new(
        enrollment: enrollment,
        barcode_image_url: attachments['barcode.png'].url,
      )
      mail(
        to: email_address.email,
        subject: t('user_mailer.in_person_ready_to_verify.subject', app_name: APP_NAME),
      )
    end
  end

  def in_person_verified(user, email_address, enrollment:)
    with_user_locale(user) do
      @hide_title = true
      @presenter = Idv::InPerson::VerificationResultsEmailPresenter.new(
        enrollment: enrollment,
        url_options: url_options,
      )
      mail(
        to: email_address.email,
        subject: t('user_mailer.in_person_verified.subject', app_name: APP_NAME),
      )
    end
  end

  def in_person_failed(user, email_address, enrollment:)
    with_user_locale(user) do
      @presenter = Idv::InPerson::VerificationResultsEmailPresenter.new(
        enrollment: enrollment,
        url_options: url_options,
      )
      mail(
        to: email_address.email,
        subject: t('user_mailer.in_person_failed.subject', app_name: APP_NAME),
      )
    end
  end

  def in_person_failed_fraud(user, email_address, enrollment:)
    with_user_locale(user) do
      @presenter = Idv::InPerson::VerificationResultsEmailPresenter.new(
        enrollment: enrollment,
        url_options: url_options,
      )
      mail(
        to: email_address.email,
        subject: t('user_mailer.in_person_failed_suspected_fraud.subject'),
      )
    end
  end

  private

  def email_should_receive_nonessential_notifications?(email)
    banlist = IdentityConfig.store.nonessential_email_banlist
    return true if banlist.empty?
    modified_email = email.gsub(/\+[^@]+@/, '@')
    !banlist.include?(modified_email)
  end
end
