class MonthlyAuthCount < ApplicationRecord
  def self.increment(user_id, issuer)
    # The following sql offers superior db performance with one write and no locking overhead
    sql = <<~SQL
      INSERT INTO monthly_auth_counts (issuer, year_month, user_id, auth_count)
      VALUES (?, ?, ?, 1)
      ON CONFLICT (issuer, year_month, user_id) DO UPDATE
      SET auth_count = monthly_auth_counts.auth_count + 1
    SQL
    year_month = Time.zone.today.strftime('%Y%m')
    query = sanitize_sql_array([sql, issuer.to_s, year_month, user_id])
    MonthlyAuthCount.connection.execute(query)
  end
end
