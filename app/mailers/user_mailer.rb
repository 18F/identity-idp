class UserMailer < ActionMailer::Base
  include Mailable
  include LocaleHelper
  before_action :attach_images
  default from: email_with_name(Figaro.env.email_from, Figaro.env.email_from_display_name),
          reply_to: email_with_name(Figaro.env.email_from, Figaro.env.email_from_display_name)

  def email_confirmation_instructions(user, email, token, request_id:, instructions:)
    presenter = ConfirmationEmailPresenter.new(user, view_context)
    @first_sentence = instructions || presenter.first_sentence
    @confirmation_period = presenter.confirmation_period
    @request_id = request_id
    @locale = locale_url_param
    @token = token
    mail(to: email, subject: t('user_mailer.email_confirmation_instructions.subject'))
  end

  def unconfirmed_email_instructions(user, email, token, request_id:, instructions:)
    presenter = ConfirmationEmailPresenter.new(user, view_context)
    @first_sentence = instructions || presenter.first_sentence
    @confirmation_period = presenter.confirmation_period
    @request_id = request_id
    @locale = locale_url_param
    @token = token
    mail(to: email, subject: t('user_mailer.email_confirmation_instructions.email_not_found'))
  end

  def signup_with_your_email(email)
    @root_url = root_url(locale: locale_url_param)
    mail(to: email, subject: t('mailer.email_reuse_notice.subject'))
  end

  def reset_password_instructions(email, token:)
    @locale = locale_url_param
    @token = token
    mail(to: email, subject: t('user_mailer.reset_password_instructions.subject'))
  end

  def password_changed(email_address, disavowal_token:)
    return unless email_should_receive_nonessential_notifications?(email_address.email)

    @disavowal_token = disavowal_token
    mail(to: email_address.email, subject: t('devise.mailer.password_updated.subject'))
  end

  def phone_added(email_address, disavowal_token:)
    return unless email_should_receive_nonessential_notifications?(email_address.email)

    @disavowal_token = disavowal_token
    mail(to: email_address.email, subject: t('user_mailer.phone_added.subject'))
  end

  def account_does_not_exist(email, request_id)
    @sign_up_email_url = sign_up_email_url(request_id: request_id, locale: locale_url_param)
    mail(to: email, subject: t('user_mailer.account_does_not_exist.subject'))
  end

  def personal_key_sign_in(email, disavowal_token:)
    return unless email_should_receive_nonessential_notifications?(email)

    @disavowal_token = disavowal_token
    mail(to: email, subject: t('user_mailer.personal_key_sign_in.subject'))
  end

  def new_device_sign_in(email_address, date, location, disavowal_token)
    return unless email_should_receive_nonessential_notifications?(email_address.email)

    @login_date = date
    @login_location = location
    @disavowal_token = disavowal_token
    mail(to: email_address.email, subject: t('user_mailer.new_device_sign_in.subject'))
  end

  def personal_key_regenerated(email)
    return unless email_should_receive_nonessential_notifications?(email)

    mail(to: email, subject: t('user_mailer.personal_key_regenerated.subject'))
  end

  def account_reset_request(email_address, account_reset)
    @token = account_reset&.request_token
    @header = t('user_mailer.account_reset_request.header')
    mail(to: email_address.email, subject: t('user_mailer.account_reset_request.subject'))
  end

  def account_reset_granted(email_address, account_reset)
    @token = account_reset&.request_token
    @granted_token = account_reset&.granted_token
    mail(to: email_address.email, subject: t('user_mailer.account_reset_granted.subject'))
  end

  def account_reset_complete(email_address)
    mail(to: email_address.email, subject: t('user_mailer.account_reset_complete.subject'))
  end

  def account_reset_cancel(email_address)
    mail(to: email_address.email, subject: t('user_mailer.account_reset_cancel.subject'))
  end

  def please_reset_password(email_address)
    mail(to: email_address, subject: t('user_mailer.please_reset_password.subject'))
  end

  def undeliverable_address(email_address)
    return unless email_should_receive_nonessential_notifications?(email_address.email)

    mail(to: email_address.email, subject: t('user_mailer.undeliverable_address.subject'))
  end

  def doc_auth_desktop_link_to_sp(email_address, application, link)
    @link = link
    @application = application
    mail(to: email_address, subject: t('user_mailer.doc_auth_link.subject'))
  end

  def letter_reminder(email)
    return unless email_should_receive_nonessential_notifications?(email)

    mail(to: email, subject: t('user_mailer.letter_reminder.subject'))
  end

  def letter_expired(email)
    return unless email_should_receive_nonessential_notifications?(email)

    mail(to: email, subject: t('user_mailer.letter_expired.subject'))
  end

  def confirm_email_and_reverify(email, account_recovery_request)
    @token = account_recovery_request.request_token
    mail(to: email.email, subject: t('recover.email.confirm'))
  end

  def add_email(user, email, token)
    presenter = ConfirmationEmailPresenter.new(user, view_context)
    @first_sentence = presenter.first_sentence
    @confirmation_period = presenter.confirmation_period
    @locale = locale_url_param
    @token = token
    mail(to: email, subject: t('user_mailer.add_email.subject'))
  end

  def email_added(email)
    return unless email_should_receive_nonessential_notifications?(email)

    mail(to: email, subject: t('user_mailer.email_added.subject'))
  end

  def email_deleted(email)
    return unless email_should_receive_nonessential_notifications?(email)

    mail(to: email, subject: t('user_mailer.email_deleted.subject'))
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
    mail(to: email, subject: t('user_mailer.deleted_accounts_report.subject'))
  end

  private

  def email_should_receive_nonessential_notifications?(email)
    banlist = JSON.parse(Figaro.env.nonessential_email_banlist || '[]')
    return true if banlist.empty?
    modified_email = email.gsub(/\+[^@]+@/, '@')
    !banlist.include?(modified_email)
  end
end
