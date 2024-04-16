# frozen_string_literal: true

# AnonymousMailer handles all email sending not associated with a user. It expects to be called
# using `with` that receives an `email` string value.
#
# You MUST deliver these messages using `deliver_now`. Anonymous messages rely on a plaintext email
# address, which is personally-identifiable information (PII). All method arguments are stored in
# the database when the email is being sent asynchronously by ActiveJob and we must not put PII in
# the database in plaintext.
#
# Example:
#
#   AnonymousMailer.with(email:).password_reset_missing_user(request_id:).deliver_now
#
class AnonymousMailer < ActionMailer::Base
  include Mailable
  include LocaleHelper

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

  def password_reset_missing_user(request_id:)
    @request_id = request_id

    mail(
      to: email,
      subject: t('anonymous_mailer.password_reset_missing_user.subject'),
    )
  end

  private

  def email
    params.fetch(:email)
  end

  def add_metadata
    message.instance_variable_set(:@_metadata, action: action_name)
  end
end
