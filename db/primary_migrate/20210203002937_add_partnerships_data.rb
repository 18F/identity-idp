class AddPartnershipsData < ActiveRecord::Migration[6.1]
  def change
    # we want this to be null: false after the initial import so we'll have a
    # second migration to add the null requirement and unique index after the
    # seed import completes.
    add_column :agencies, :abbreviation, :string

    create_table :partner_account_statuses do |t|
      t.string :name, null: false
      t.integer :order, null: false
      t.string :partner_name

      t.index :name, unique: true
      t.index :order, unique: true
    end

    create_table :partner_accounts do |t|
      t.string :name, null: false
      t.text :description
      t.string :requesting_agency, null: false
      t.integer :crm_id
      t.date :became_partner

      t.references :agency, foreign_key: true
      t.references :partner_account_status, foreign_key: true

      t.index :name, unique: true
      t.index :requesting_agency, unique: true
    end

    create_table :iaa_statuses do |t|
      t.string :name, null: false
      t.integer :order, null: false
      t.string :partner_name

      t.index :name, unique: true
      t.index :order, unique: true
    end

    create_table :iaa_gtcs do |t|
      t.string :gtc_number, null: false
      t.integer :mod_number, null: false, default: 0
      t.date :start_date
      t.date :end_date
      t.decimal :estimated_amount, precision: 12, scale: 2

      t.references :partner_account, foreign_key: true
      t.references :iaa_status, foreign_key: true

      t.index :gtc_number, unique: true
    end

    create_table :iaa_orders do |t|
      t.integer :order_number, null: false
      t.integer :mod_number, null: false, default: 0
      t.date :start_date
      t.date :end_date
      t.decimal :estimated_amount, precision: 12, scale: 2
      t.integer :pricing_model, null: false, default: 2

      t.references :iaa_gtc, foreign_key: true
      t.references :iaa_status, foreign_key: true

      t.index [:iaa_gtc_id, :order_number], unique: true
    end

    create_table :integration_statuses do |t|
      t.string :name, null: false
      t.integer :order, null: false
      t.string :partner_name

      t.index :name, unique: true
      t.index :order, unique: true
    end

    create_table :integrations do |t|
      t.string :issuer, null: false
      t.string :name, null: false
      t.integer :dashboard_identifier

      t.references :partner_account, foreign_key: true
      t.references :integration_status, foreign_key: true
      t.references :service_provider, foreign_key: true

      t.index :issuer, unique: true
      t.index :dashboard_identifier, unique: true
    end

    create_table :integration_usages do |t|
      t.references :iaa_order, foreign_key: true
      t.references :integration, foreign_key: true

      t.index [:iaa_order_id, :integration_id], unique: true
    end
  end
end
