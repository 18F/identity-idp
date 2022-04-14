class VerificationErrorsReport
  def self.call(service_provider, since)
    report_sql = <<~SQL
      SELECT uuid,welcome_view_at,document_capture_submit_at,ssn_view_at,
             verify_submit_at,ssn_view_at,verify_phone_submit_at,encrypt_view_at,enter_info_view_at
      FROM doc_auth_logs, users
      WHERE users.id=doc_auth_logs.user_id AND issuer='%s' and verified_view_at is null AND welcome_view_at > '%s'
    SQL
    sql = format(report_sql, service_provider, since)
    ActiveRecord::Base.connection.execute(sql)
  end
end
