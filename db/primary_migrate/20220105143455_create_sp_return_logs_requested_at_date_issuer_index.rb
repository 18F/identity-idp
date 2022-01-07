class CreateSpReturnLogsRequestedAtDateIssuerIndex < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!

  def up
    safety_assured do
      execute <<-SQL
        CREATE INDEX CONCURRENTLY index_sp_return_logs_on_requested_at_date_issuer
        ON public.sp_return_logs
        USING btree ((requested_at::date), issuer)
        WHERE (returned_at IS NOT NULL);
      SQL
    end
  end

  def down
    execute "DROP INDEX index_sp_return_logs_on_requested_at_date_issuer"
  end
end
