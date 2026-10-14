# frozen_string_literal: true

# Records an approval or revocation made on the account page in the person's account history and
# tells them by email, with the usual disavowal link, the same way connecting or disconnecting a
# service is reported today. One event and one email cover all the applications of one action.
# Relies on ApplicationController's event creator for the history row and disavowal token.
module DelegatedAccessNotificationConcern
  extend ActiveSupport::Concern

  # @param service_provider [ServiceProvider, nil] nil when the action spanned every service
  #   provider (ending all delegated access)
  # @param applications [Array<ServiceProvider>]
  def notify_delegation_approved(service_provider:, applications:)
    _event, disavowal_token = create_user_event_with_disavowal(:delegation_approved)
    deliver_delegation_mail(
      :delegation_approved, service_provider:, applications:, disavowal_token:
    )
  end

  def notify_delegation_revoked(service_provider:, applications:)
    _event, disavowal_token = create_user_event_with_disavowal(:delegation_revoked)
    deliver_delegation_mail(
      :delegation_revoked, service_provider:, applications:, disavowal_token:
    )
  end

  private

  def deliver_delegation_mail(mailer_method, service_provider:, applications:, disavowal_token:)
    application_names = applications.map do |application|
      application.delegation_display_name_for.presence || application.display_name
    end
    current_user.confirmed_email_addresses.each do |email_address|
      UserMailer.with(user: current_user, email_address:)
        .public_send(
          mailer_method,
          sp_name: service_provider&.friendly_name,
          application_names:,
          disavowal_token:,
        )
        .deliver_now_or_later
    end
  end
end
