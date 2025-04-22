# frozen_string_literal: true

class DuplicateAccountsReport
  def initialize(service_provider_arr)
    @service_provider_arr = service_provider_arr
  end

  def self.call(service_provider_arr)
    identities_sql(service_provider_arr)
  end

  def self.identities_sql(sp_array)
    query = <<-SQL
      WITH non_unique_ssn_signatures AS (
        SELECT ssn_signature
        FROM profiles
        GROUP BY ssn_signature
        HAVING COUNT(*) > 1
      )
      SELECT 
        i.service_provider,
        u.uuid,
        u.updated_at,
        sp.friendly_name,
        p.activated_at,
        p.ssn_signature
      FROM identities i
      JOIN users u ON i.user_id = u.id
      JOIN service_providers sp ON i.service_provider = sp.issuer
      JOIN profiles p ON u.id = p.user_id
      JOIN non_unique_ssn_signatures nus ON p.ssn_signature = nus.ssn_signature
      WHERE 
        i.service_provider IN (?)
        AND i.ial = 2
        AND i.last_authenticated_at BETWEEN ? AND ?
    SQL

    ActiveRecord::Base.connection.execute(
      ApplicationRecord.sanitize_sql_array(
        [
          query,
          sp_array,
          Date.yesterday.beginning_of_day,
          Date.yesterday.end_of_day,
        ],
      ),
    )
  end
end
