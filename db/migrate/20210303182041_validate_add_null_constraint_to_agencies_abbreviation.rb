class ValidateAddNullConstraintToAgenciesAbbreviation < ActiveRecord::Migration[6.1]
  def up
    safety_assured do
      # just in case, copy over the name to abbreviation in case an environment is
      # missing the abbreviations. This will be overriden by the contents of the
      # YAML file when db:seed is run, but allows us to set the null constraint
      # safely. I'm using SQL just so we're not dependent on the Model class.
      execute 'UPDATE agencies SET abbreviation = name WHERE abbreviation IS NULL'

      # following guidance from strong_migration
      execute 'ALTER TABLE "agencies" VALIDATE CONSTRAINT "agencies_abbreviation_null"'

      change_column_null :agencies, :abbreviation, false

      execute 'ALTER TABLE "agencies" DROP CONSTRAINT "agencies_abbreviation_null"'
    end
  end

  def down
    safety_assured do
      execute 'ALTER TABLE "agencies" ADD CONSTRAINT "agencies_abbreviation_null" CHECK ("abbreviation" IS NOT NULL) NOT VALID'

      change_column_null :agencies, :abbreviation, true
    end
  end
end
