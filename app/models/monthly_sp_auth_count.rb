class MonthlySpAuthCount < ApplicationRecord
  def self.increment(user_id, issuer, ial)
    # The following sql offers superior db performance with one write and no locking overhead
    sql = <<~SQL
      INSERT INTO monthly_sp_auth_counts (issuer, ial, year_month, user_id, auth_count)
      VALUES (?, ?, ?, ?, 1)
      ON CONFLICT (issuer, ial, year_month, user_id) DO UPDATE
      SET auth_count = monthly_sp_auth_counts.auth_count + 1
    SQL
    year_month = Time.zone.today.strftime('%Y%m')
    service_provider = ServiceProvider.from_issuer(issuer)
    ial_context = IalContext.new(ial: ial, service_provider: service_provider)
    ial_1_or_2 = ial_context.ial2_or_greater? ? 2 : 1
    query = sanitize_sql_array([sql, issuer.to_s, ial_1_or_2, year_month, user_id])
    MonthlySpAuthCount.connection.execute(query)
  end
end