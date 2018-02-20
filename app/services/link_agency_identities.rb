class LinkAgencyIdentities
  AGENCY_INFO = Struct.new(:issuer, :priority, :agency_id)

  def link
    sps = sps_to_link
    sps.sort! { |spa, spb| spa.priority <=> spb.priority }
    sps.each { |sp| link_service_provider(sp.agency_id, sp.issuer) }
    log 'Complete'
  end

  def self.report
    report_sql = <<~SQL
      SELECT DISTINCT ag.name, id.uuid AS old_uuid, ai.uuid AS new_uuid
      FROM agency_identities ai, service_providers sp, identities id, agencies ag
      WHERE ag.id = ai.agency_id AND ag.id = sp.agency_id AND ai.user_id = id.user_id AND
        sp.issuer = id.service_provider AND id.uuid != ai.uuid
      ORDER BY ag.name ASC, id.uuid ASC
    SQL
    ActiveRecord::Base.connection.execute(report_sql)
  end

  private

  def log(msg)
    Rails.logger.info(msg)
  end

  def sps_to_link
    sps = []
    service_providers.each do |issuer, config|
      priority, agency_id = agency_info(config)
      sps << AGENCY_INFO.new(issuer, priority, agency_id) if priority && (agency_id != 0)
    end
    sps
  end

  def agency_info(config)
    priority = (config['uuid_priority'] || 1_000_000).to_i
    [priority, config['agency_id'].to_i]
  end

  def link_service_provider(agency_id, service_provider)
    log "agency_id=#{agency_id} sp=#{service_provider}"
    linker_sql = <<~SQL
      INSERT INTO agency_identities (user_id,agency_id,uuid)
      (SELECT user_id,%d,MAX(uuid) FROM identities WHERE service_provider='%s' GROUP BY user_id)
      ON CONFLICT DO NOTHING
    SQL
    sql = format(linker_sql, agency_id, service_provider, agency_id)
    ActiveRecord::Base.connection.execute(sql)
  end

  def service_providers
    content = ERB.new(Rails.root.join('config', 'service_providers.yml').read).result
    YAML.safe_load(content).fetch(Rails.env, {})
  end
end
