class LinkAgencyIdentities
  AGENCY_INFO = Struct.new(:issuer, :priority, :agency_id)

  def link
    sps = sps_to_link
    sps.sort! { |spa, spb| spa.priority <=> spb.priority }
    sps.each { |sp| link_service_provider(sp.agency_id, sp.issuer) }
  end

  private

  def sps_to_link
    sps = []
    service_providers.each do |issuer, config|
      priority = config['uuid_priority']
      agency_id = config['agency_id']
      if priority && agency_id
        sps << AGENCY_INFO.new(issuer, priority, agency_id)
      end
    end
    sps
  end

  def link_service_provider(agency_id, service_provider)
    linker_sql = <<~SQL
      INSERT INTO agency_identities (user_id,agency_id,uuid)
      SELECT user_id,%d,max(uuid)
      FROM identities
      WHERE service_provider='%s'
      AND user_id NOT IN (SELECT user_id FROM agency_identities WHERE agency_id=%d)
      GROUP BY user_id
    SQL
    sql = format(linker_sql, agency_id, service_provider, agency_id)
    ActiveRecord::Base.connection.execute(sql)
  end

  def service_providers
    content = ERB.new(Rails.root.join('config', 'service_providers.yml').read).result
    YAML.safe_load(content).fetch(Rails.env, {})
  end
end
