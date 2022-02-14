module Db
  class SpReturnLog
    # rubocop:disable Rails/SkipsModelValidations
    def self.update_user(request_id:, user_id:)
      return if request_id.blank?
      ::SpReturnLog.where(request_id: request_id).update_all(user_id: user_id)
      nil
    end

    def self.add_return(request_id:, user_id:, billable:, ial:)
      ::SpReturnLog.where(request_id: request_id).update_all(
        user_id: user_id,
        returned_at: Time.zone.now,
        billable: billable,
        ial: ial,
      )
      nil
    end
    # rubocop:enable Rails/SkipsModelValidations

    def self.create_request(request_id:, ial:, issuer:)
      ::SpReturnLog.create!(
        request_id: request_id,
        ial: ial,
        issuer: issuer,
        requested_at: Time.zone.now,
      )
    rescue ActiveRecord::RecordNotUnique
      nil
    end

    def self.success_rate_by_sp
      sql = <<~SQL
        SELECT sp_return_logs.issuer, sp_return_logs.ial, MAX(app_id) AS app_id,
               count(returned_at)::float/count(requested_at) as return_rate
        FROM sp_return_logs, service_providers
        WHERE sp_return_logs.issuer = service_providers.issuer
        GROUP BY sp_return_logs.issuer, sp_return_logs.ial
        ORDER BY issuer, ial
      SQL
      ActiveRecord::Base.connection.execute(sql)
    end
  end
end
