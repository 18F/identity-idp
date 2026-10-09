# frozen_string_literal: true

# Update ServiceProvider table by pulling from the Dashboard app API (lower environments only)
#
# Delegated-access fields arrive in the same payload as every other service provider field and
# are written straight through, with one nested list: token_exchange_resource_servers, the API
# URLs of an agency application, handled by #sync_resource_servers.
#
# Dependency: the partner Dashboard (identity-dashboard) does not yet expose the delegated-access
# fields (token_exchange_enabled_sp, the delegation_* content, delegation_application,
# delegation_scope_value, allowed_delegation_service_providers, the agency content, or nested
# token_exchange_resource_servers). Until it does, payloads carry none of them and
# `rake delegated_access:seed` loads that data in non-production environments.
class ServiceProviderUpdater
  SP_PROTECTED_ATTRIBUTES = %i[
    created_at
    id
    updated_at
  ].to_set.freeze

  SP_IGNORED_ATTRIBUTES = %i[
    cert
  ].freeze

  # Written through #sync_resource_servers rather than as a column.
  SP_NESTED_ATTRIBUTES = %i[
    token_exchange_resource_servers
  ].freeze

  RS_PROTECTED_ATTRIBUTES = %i[
    id
    created_at
    updated_at
  ].freeze

  def run(service_provider = nil)
    if service_provider.present?
      update_local_caches(ActiveSupport::HashWithIndifferentAccess.new(service_provider))
    else
      dashboard_service_providers.each do |dashboard_service_provider|
        update_local_caches(
          ActiveSupport::HashWithIndifferentAccess.new(dashboard_service_provider),
        )
      end
    end
  end

  private

  def update_local_caches(service_provider)
    update_cache(service_provider)
  end

  def update_cache(service_provider)
    issuer = service_provider['issuer']
    if service_provider['active'] == true
      create_or_update_service_provider(issuer, service_provider)
    else
      ServiceProvider.where(issuer: issuer).destroy_all
    end
  end

  def create_or_update_service_provider(issuer, service_provider)
    sp = ServiceProvider.find_by(issuer: issuer)
    sp = sync_model(sp, cleaned_service_provider(service_provider))
    sync_resource_servers(sp, service_provider['token_exchange_resource_servers'])
  end

  def sync_model(sp, cleaned_attributes)
    if sp
      sp.update(cleaned_attributes)
      sp
    else
      ServiceProvider.create!(cleaned_attributes)
    end
  end

  def cleaned_service_provider(service_provider)
    service_provider.except(
      *SP_PROTECTED_ATTRIBUTES, *SP_IGNORED_ATTRIBUTES, *SP_NESTED_ATTRIBUTES
    )
  end

  # The application's API URLs, in the same shape as service_providers.yml. Each is upserted by
  # identifier. A URL missing from the payload is deactivated rather than deleted: approvals and
  # tokens may reference it, and `active: false` already means "stop issuing for this URL".
  def sync_resource_servers(sp, resource_servers)
    return if sp.nil? || resource_servers.nil?

    seen = []
    Array(resource_servers).each do |rs_attrs|
      rs_attrs = ActiveSupport::HashWithIndifferentAccess.new(rs_attrs)
      rs = sp.token_exchange_resource_servers
        .find_or_initialize_by(identifier: rs_attrs[:identifier])
      rs.update!(
        rs_attrs
          .except(
            *RS_PROTECTED_ATTRIBUTES, :identifier, :attempts_service_provider,
            :service_provider_id
          )
          .merge(
            attempts_service_provider: ServiceProvider.find_by(
              issuer: rs_attrs[:attempts_service_provider],
            ),
          ),
      )
      seen << rs.id
    end
    # rubocop:disable Rails/SkipsModelValidations
    sp.token_exchange_resource_servers.where.not(id: seen).update_all(active: false)
    # rubocop:enable Rails/SkipsModelValidations
  end

  def url
    IdentityConfig.store.dashboard_url
  end

  def dashboard_service_providers
    body = dashboard_response.body
    return parse_service_providers(body) if dashboard_response.status == 200
    log_error "Failed to parse response from #{url}: #{body}"
    []
  rescue StandardError
    log_error "Failed to contact #{url}"
    []
  end

  def parse_service_providers(body)
    JSON.parse(body)
  end

  def dashboard_response
    @dashboard_response ||= Faraday.get(url)
  end

  def log_error(msg)
    Rails.logger.error msg
  end
end
