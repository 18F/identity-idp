# frozen_string_literal: true

# Marks how a billing row came to be written: `direct` for the handoff of a sign-in to the
# service provider named in `issuer`, `delegated` for a token exchange that issued a delegated
# token for an agency API, written under the API's billing issuer. Reports that break out
# delegated use filter on it; the acting service provider, the API and whether the person
# verified identity in that sign-in are read from the token issuance record the row is linked to
# through the billing adjustments table, not stored here. Rows written before the column existed
# read as `direct`.
class AddAccessTypeToSpReturnLogs < ActiveRecord::Migration[8.1]
  def change
    add_column :sp_return_logs, :access_type, :string, default: 'direct',
                                                       comment: 'sensitive=false'
  end
end
