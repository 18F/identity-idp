class VerificationErrorsReport
  def self.call(service_provider, since)
    report_sql = <<~SQL
      SELECT 
        agency_identities.uuid,
        document_capture_submit_at,
        encrypt_view_at,
        enter_info_view_at,
        ssn_view_at,
        verify_phone_submit_at,
        verify_submit_at,
        welcome_view_at
      FROM doc_auth_logs, users, agency_identities, service_providers
      WHERE 
        users.id=doc_auth_logs.user_id AND 
        service_providers.issuer = %{issuer} AND 
        agency_identities.agency_id = service_providers.agency_id AND 
        agency_identities.user_id = users.id AND 
        doc_auth_logs.issuer=%{issuer} AND
        verified_view_at is null AND
        welcome_view_at > %{since}
      ORDER BY agency_identities.uuid ASC
    SQL
    sql = format(
      report_sql,
      issuer: ActiveRecord::Base.connection.quote(service_provider),
      since: ActiveRecord::Base.connection.quote(since),
    )
    ActiveRecord::Base.connection.execute(sql)
  end
end
