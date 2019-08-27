# Update ServiceProvider table by pulling from the Dashboard app API (lower environments only)
class ServiceProviderUpdater
  SP_PROTECTED_ATTRIBUTES = %i[
    created_at
    id
    native
    updated_at
  ].to_set.freeze

  HT_PROTECTED_ATTRIBUTES = %i[
    id
    created_at
    service_provider_id
    updated_at
  ].to_set.freeze

  def run
    dashboard_service_providers.each do |service_provider|
      update_local_caches(HashWithIndifferentAccess.new(service_provider))
    end
  end

  private

  def update_local_caches(service_provider)
    issuer = service_provider['issuer']
    update_cache(issuer, service_provider)
  end

  def update_cache(issuer, service_provider)
    if service_provider['active'] == true
      create_or_update_service_provider(issuer, service_provider)
    else
      ServiceProvider.where(issuer: issuer, native: false).destroy_all
    end
  end

  def create_or_update_service_provider(issuer, service_provider)
    sp = ServiceProvider.from_issuer(issuer)
    return if sp.native?
    sync_model(sp, cleaned_service_provider(service_provider))
  end

  def sync_model(sp, cleaned_attributes)
    clean_sp_attributes  = cleaned_attributes.except('help_text')
    if sp.is_a?(NullServiceProvider)
      new_sp = ServiceProvider.create!(clean_sp_attributes)
      create_or_update_help_text(new_sp, cleaned_attributes)
      new_sp
    else
      sp.update(clean_sp_attributes)
      create_or_update_help_text(sp, cleaned_attributes)
    end
  end

  def create_or_update_help_text(sp, cleaned_attributes)
    clean_ht_attributes = cleaned_attributes['help_text']
    ht = sp.help_text
    if clean_ht_attributes.present?
      if ht.present?
        ht.update(clean_ht_attributes&.except(*HT_PROTECTED_ATTRIBUTES))
      else
        sp.help_text = HelpText.create!(clean_ht_attributes.except(*HT_PROTECTED_ATTRIBUTES))
      end
    end
  end

  def cleaned_service_provider(service_provider)
    service_provider.except(*SP_PROTECTED_ATTRIBUTES)
  end

  def url
    Figaro.env.dashboard_url
  end

  def dashboard_service_providers
    body = dashboard_response.body
    return parse_service_providers(body) if dashboard_response.code == 200
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
    @_dashboard_response ||= HTTParty.get(url)
  end

  def log_error(msg)
    Rails.logger.error msg
  end
end
