class AddEmailNameIdFormatToServiceProviders < ActiveRecord::Migration[6.1]
  def change
    add_column :service_providers, :email_nameid_format_allowed, :boolean
    change_column_default :service_providers, :email_nameid_format_allowed, from: nil, to: false

    reversible do |dir|
      dir.up do
        if IdentityConfig.store.respond_to?(:issuers_with_email_nameid_format)
          issuers = IdentityConfig.store.issuers_with_email_nameid_format
          unless issuers.empty?
            query = <<~SQL
              UPDATE service_providers
              SET email_nameid_format_allowed = 't'
              WHERE issuer in (#{issuers.map { |i| "'#{i}'" }.join(', ')})
            SQL
            ActiveRecord::Base.connection.execute(query)
          end
        end
      end
    end
  end
end
