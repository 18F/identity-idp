class DeletedAccountsReport
  def self.call(service_provider, days_ago)
    report_sql = <<~SQL
      SELECT uuid,last_authenticated_at
      FROM identities
      WHERE user_id not in (SELECT id FROM users)
      AND service_provider='%s'
      AND last_authenticated_at > '%s'
    SQL
    sql = format(report_sql, service_provider, days_ago.to_i.days.ago)
    ActiveRecord::Base.connection.execute(sql)
  end
end
