class MonthlySpAuthCount < ApplicationRecord
  def self.increment(user_id, issuer, ial)
    # The following sql offers superior db performance with one write and no locking overhead
    sql = <<~SQL
      INSERT INTO monthly_sp_auth_counts (issuer, ial, year_month, user_id, auth_count)
      VALUES (?, ?, ?, ?, 1)
      ON CONFLICT (issuer, year_month, user_id) DO UPDATE
      SET auth_count = monthly_sp_auth_counts.auth_count + 1
    SQL
    year_month = Time.zone.today.strftime('%Y%m')
    query = sanitize_sql_array([sql, issuer.to_s, ial.to_i, year_month, user_id])
    MonthlySpAuthCount.connection.execute(query)
  end
end
