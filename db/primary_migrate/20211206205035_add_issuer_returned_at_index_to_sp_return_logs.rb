class AddIssuerReturnedAtIndexToSpReturnLogs < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!

  def change
    add_index(
      :sp_return_logs,
      %i[issuer requested_at],
      algorithm: :concurrently,
    )
  end
end
