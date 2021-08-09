class ValidateAddNullCheckConstraintToIaaDates < ActiveRecord::Migration[6.1]
  def up
    # following guidance from strong_migration
    safety_assured do
      execute 'ALTER TABLE "iaa_gtcs" VALIDATE CONSTRAINT "iaa_gtcs_start_date_null"'
      execute 'ALTER TABLE "iaa_gtcs" VALIDATE CONSTRAINT "iaa_gtcs_end_date_null"'
      execute 'ALTER TABLE "iaa_orders" VALIDATE CONSTRAINT "iaa_orders_start_date_null"'
      execute 'ALTER TABLE "iaa_orders" VALIDATE CONSTRAINT "iaa_orders_end_date_null"'
    end
  end

  def down
  end
end
