class MonthlySpAuthCount < ApplicationRecord
  # rubocop:disable Rails/InverseOf
  belongs_to :user
  belongs_to :service_provider,
             foreign_key: 'issuer',
             primary_key: 'issuer'
  # rubocop:enable Rails/InverseOf

  def self.increment(user_id:, service_provider:, ial:)
    # The following sql offers superior db performance with one write and no locking overhead
    sql = <<~SQL
      INSERT INTO monthly_sp_auth_counts (issuer, ial, year_month, user_id, auth_count)
      VALUES (?, ?, ?, ?, 1)
      ON CONFLICT (issuer, ial, year_month, user_id) DO UPDATE
      SET auth_count = monthly_sp_auth_counts.auth_count + 1
    SQL
    year_month = Time.zone.today.strftime('%Y%m')
    current_user = User.find_by(id: user_id)
    ial_context = IalContext.new(ial: ial, service_provider: service_provider, user: current_user)
    query = sanitize_sql_array(
      [sql,
       service_provider&.issuer.to_s,
       ial_context.bill_for_ial_1_or_2,
       year_month,
       user_id],
    )
    MonthlySpAuthCount.connection.execute(query)
  end
end
