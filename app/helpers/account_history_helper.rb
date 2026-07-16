# frozen_string_literal: true

module AccountHistoryHelper
  def account_history_event_title(event)
    return event.event_type unless account_history_service_provider_event?(event)

    if event.return_to_sp_url.present?
      t(
        'event_types.authenticated_at_html',
        service_provider_link_html: link_to(event.display_name, event.return_to_sp_url),
      )
    else
      t('event_types.authenticated_at', service_provider: event.display_name)
    end
  end

  def account_history_event_description(event)
    return if account_history_service_provider_event?(event)

    event.last_sign_in_location_and_ip.presence
  end

  private

  def account_history_service_provider_event?(event)
    event.is_a?(ServiceProviderIdentity)
  end
end
