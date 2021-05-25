class AddNullCheckConstraintToIaaDates < ActiveRecord::Migration[6.1]
  def up
    # following guidance from strong_migration
    safety_assured do
      execute 'ALTER TABLE "iaa_gtcs" ADD CONSTRAINT "iaa_gtcs_start_date_null" CHECK("start_date" IS NOT NULL) NOT VALID'
      execute 'ALTER TABLE "iaa_gtcs" ADD CONSTRAINT "iaa_gtcs_end_date_null" CHECK("end_date" IS NOT NULL) NOT VALID'
      execute 'ALTER TABLE "iaa_orders" ADD CONSTRAINT "iaa_orders_start_date_null" CHECK("start_date" IS NOT NULL) NOT VALID'
      execute 'ALTER TABLE "iaa_orders" ADD CONSTRAINT "iaa_orders_end_date_null" CHECK("end_date" IS NOT NULL) NOT VALID'
    end
  end

  def down
    safety_assured do
      execute 'ALTER TABLE "iaa_gtcs" DROP CONSTRAINT "iaa_gtcs_start_date_null"'
      execute 'ALTER TABLE "iaa_gtcs" DROP CONSTRAINT "iaa_gtcs_end_date_null"'
      execute 'ALTER TABLE "iaa_orders" DROP CONSTRAINT "iaa_orders_start_date_null"'
      execute 'ALTER TABLE "iaa_orders" DROP CONSTRAINT "iaa_orders_end_date_null"'
    end
  end
end
