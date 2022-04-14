class VerificationErrorsReport
  def self.call(service_provider, since)
    report_sql = <<~SQL
      SELECT agency_identities.uuid,welcome_view_at,document_capture_submit_at,ssn_view_at,
             verify_submit_at,ssn_view_at,verify_phone_submit_at,encrypt_view_at,enter_info_view_at
      FROM doc_auth_logs, users, agency_identities, service_providers
      WHERE 
        users.id=doc_auth_logs.user_id AND 
        service_providers.issuer = '%s' AND 
        agency_identities.agency_id = service_providers.agency_id AND 
        agency_identities.user_id = users.id AND 
        doc_auth_logs.issuer='%s' AND
        verified_view_at is null AND
        welcome_view_at > '%s'
    SQL
    sql = format(report_sql, service_provider, service_provider, since)
    ActiveRecord::Base.connection.execute(sql)
  end
end
