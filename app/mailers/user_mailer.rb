class UserMailer < ActionMailer::Base
  include Mailable
  include LocaleHelper

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

  def email_confirmation_instructions(user, email, token, request_id:, instructions:)
    with_user_locale(user) do
      presenter = ConfirmationEmailPresenter.new(user, view_context)
      @first_sentence = instructions || presenter.first_sentence
      @confirmation_period = presenter.confirmation_period
      @request_id = request_id
      @locale = locale_url_param
      @token = token
      mail(to: email, subject: t('user_mailer.email_confirmation_instructions.subject'))
    end
  end

  def unconfirmed_email_instructions(user, email, token, request_id:, instructions:)
    with_user_locale(user) do
      presenter = ConfirmationEmailPresenter.new(user, view_context)
      @first_sentence = instructions || presenter.first_sentence
      @confirmation_period = presenter.confirmation_period
      @request_id = request_id
      @locale = locale_url_param
      @token = token
      mail(to: email, subject: t('user_mailer.email_confirmation_instructions.email_not_found'))
    end
  end

  def signup_with_your_email(user, email)
    with_user_locale(user) do
      @root_url = root_url(locale: locale_url_param)
      mail(to: email, subject: t('mailer.email_reuse_notice.subject'))
    end
  end

  def reset_password_instructions(user, email, token:)
    with_user_locale(user) do
      @locale = locale_url_param
      @token = token
      mail(to: email, subject: t('user_mailer.reset_password_instructions.subject'))
    end
  end

  def password_changed(user, email_address, disavowal_token:)
    return unless email_should_receive_nonessential_notifications?(email_address.email)

    with_user_locale(user) do
      @disavowal_token = disavowal_token
      mail(to: email_address.email, subject: t('devise.mailer.password_updated.subject'))
    end
  end

  def phone_added(user, email_address, disavowal_token:)
    return unless email_should_receive_nonessential_notifications?(email_address.email)

    with_user_locale(user) do
      @disavowal_token = disavowal_token
      mail(to: email_address.email, subject: t('user_mailer.phone_added.subject'))
    end
  end

  def account_does_not_exist(email, request_id)
    @sign_up_email_url = sign_up_email_url(request_id: request_id, locale: locale_url_param)
    mail(to: email, subject: t('user_mailer.account_does_not_exist.subject', app_name: APP_NAME))
  end

  def personal_key_sign_in(user, email, disavowal_token:)
    return unless email_should_receive_nonessential_notifications?(email)

    with_user_locale(user) do
      @disavowal_token = disavowal_token
      mail(to: email, subject: t('user_mailer.personal_key_sign_in.subject'))
    end
  end

  def new_device_sign_in(user:, email_address:, date:, location:, disavowal_token:)
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

  def personal_key_regenerated(user, email)
    return unless email_should_receive_nonessential_notifications?(email)

    with_user_locale(user) do
      mail(to: email, subject: t('user_mailer.personal_key_regenerated.subject'))
    end
  end

  def account_reset_request(user, email_address, account_reset)
    with_user_locale(user) do
      @token = account_reset&.request_token
      @header = t('user_mailer.account_reset_request.header')
      mail(
        to: email_address.email,
        subject: t('user_mailer.account_reset_request.subject', app_name: APP_NAME),
      )
    end
  end

  def account_reset_granted(user, email_address, account_reset)
    with_user_locale(user) do
      @token = account_reset&.request_token
      @granted_token = account_reset&.granted_token
      mail(
        to: email_address.email,
        subject: t('user_mailer.account_reset_granted.subject', app_name: APP_NAME),
      )
    end
  end

  def account_reset_complete(user, email_address)
    with_user_locale(user) do
      mail(to: email_address.email, subject: t('user_mailer.account_reset_complete.subject'))
    end
  end

  def account_reset_cancel(user, email_address)
    with_user_locale(user) do
      mail(to: email_address.email, subject: t('user_mailer.account_reset_cancel.subject'))
    end
  end

  def please_reset_password(user, email_address)
    with_user_locale(user) do
      mail(
        to: email_address,
        subject: t('user_mailer.please_reset_password.subject', app_name: APP_NAME),
      )
    end
  end

  def doc_auth_desktop_link_to_sp(user, email_address, application, link)
    with_user_locale(user) do
      @link = link
      @application = application
      mail(to: email_address, subject: t('user_mailer.doc_auth_link.subject'))
    end
  end

  def letter_reminder(user, email)
    return unless email_should_receive_nonessential_notifications?(email)

    with_user_locale(user) do
      mail(to: email, subject: t('user_mailer.letter_reminder.subject'))
    end
  end

  def add_email(user, email, token)
    with_user_locale(user) do
      presenter = ConfirmationEmailPresenter.new(user, view_context)
      @first_sentence = presenter.first_sentence
      @confirmation_period = presenter.confirmation_period
      @locale = locale_url_param
      @token = token
      mail(to: email, subject: t('user_mailer.add_email.subject'))
    end
  end

  def email_added(user, email)
    return unless email_should_receive_nonessential_notifications?(email)

    with_user_locale(user) do
      mail(to: email, subject: t('user_mailer.email_added.subject'))
    end
  end

  def email_deleted(user, email)
    return unless email_should_receive_nonessential_notifications?(email)

    with_user_locale(user) do
      mail(to: email, subject: t('user_mailer.email_deleted.subject'))
    end
  end

  def add_email_associated_with_another_account(email)
    @root_url = root_url(locale: locale_url_param)
    mail(to: email, subject: t('mailer.email_reuse_notice.subject'))
  end

  def sps_over_quota_limit(email)
    mail(to: email, subject: t('user_mailer.sps_over_quota_limit.subject'))
  end

  def deleted_user_accounts_report(email:, name:, issuers:, data:)
    @name = name
    @issuers = issuers
    @data = data
    attachments['deleted_user_accounts.csv'] = data
    mail(to: email, subject: t('user_mailer.deleted_accounts_report.subject'))
  end

  def verification_errors_report(email:, name:, issuers:, data:)
    @name = name
    @issuers = issuers
    @data = data
    attachments['verification_errors.csv'] = data
    mail(to: email, subject: t('user_mailer.verification_errors_report.subject'))
  end

  def account_verified(user, email_address, date_time:, sp_name:, disavowal_token:)
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

  private

  def email_should_receive_nonessential_notifications?(email)
    banlist = IdentityConfig.store.nonessential_email_banlist
    return true if banlist.empty?
    modified_email = email.gsub(/\+[^@]+@/, '@')
    !banlist.include?(modified_email)
  end
end
