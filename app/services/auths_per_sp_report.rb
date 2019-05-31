class AuthsPerSpReport
  def self.call(days_ago)
    report_sql = <<~SQL
      SELECT agency, friendly_name, service_provider, cnt
      FROM service_providers,
      (SELECT service_provider, COUNT(*) as cnt
      FROM identities
      GROUP BY service_provider) as sps_n_counts
      WHERE service_providers.issuer = sps_n_counts.service_provider
      ORDER BY cnt DESC
    SQL
    ActiveRecord::Base.connection.execute(format(report_sql, days_ago.days.ago))
  end
end
