class DeletedAccountsReport
  def self.call(service_provider, days_ago)
    report_sql = <<~SQL
      SELECT last_authenticated_at, identity_uuid FROM
      (SELECT ids.last_authenticated_at AS last_authenticated_at,
              ids.uuid AS identity_uuid, us.id AS users_id
      FROM identities AS ids LEFT JOIN users AS us ON ids.user_id=us.id
      WHERE service_provider='%s' AND last_authenticated_at > '%s') AS tbl
      WHERE users_id IS NULL ORDER BY last_authenticated_at ASC
    SQL
    sql = format(report_sql, service_provider, days_ago.to_i.days.ago)
    ActiveRecord::Base.connection.execute(sql)
  end
end
