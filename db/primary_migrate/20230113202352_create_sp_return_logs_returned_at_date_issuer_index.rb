class CreateSpReturnLogsReturnedAtDateIssuerIndex < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def up
    safety_assured do
      execute <<-SQL
        CREATE INDEX CONCURRENTLY index_sp_return_logs_on_returned_at_date_issuer
        ON public.sp_return_logs
        USING btree ((returned_at::date), issuer)
        WHERE (billable = true and returned_at IS NOT NULL);
      SQL
    end
  end

  def down
    safety_assured do
      execute "DROP INDEX index_sp_return_logs_on_returned_at_date_issuer"
    end
  end
end
