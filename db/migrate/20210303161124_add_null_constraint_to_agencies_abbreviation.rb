class AddNullConstraintToAgenciesAbbreviation < ActiveRecord::Migration[6.1]
  def up
    # following guidance from strong_migration
    safety_assured do
      execute 'ALTER TABLE "agencies" ADD CONSTRAINT "agencies_abbreviation_null" CHECK ("abbreviation" IS NOT NULL) NOT VALID'
    end
  end

  def down
    safety_assured do
      execute 'ALTER TABLE "agencies" DROP CONSTRAINT "agencies_abbreviation_null"'
    end
  end
end
