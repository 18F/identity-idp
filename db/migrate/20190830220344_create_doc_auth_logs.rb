class CreateDocAuthLogs < ActiveRecord::Migration[5.1]
  def change
    create_table :doc_auth_logs do |t|
      t.integer  :user_id, null: false
      t.datetime :welcome_view_at
      t.integer  :welcome_view_count, default: 0
      t.datetime :upload_view_at
      t.integer  :upload_view_count, default: 0
      t.datetime :send_link_view_at
      t.integer  :send_link_view_count, default: 0
      t.datetime :link_sent_view_at
      t.integer  :link_sent_view_count, default: 0
      t.datetime :email_sent_view_at
      t.integer  :email_sent_view_count, default: 0
      t.datetime :front_image_view_at
      t.integer  :front_image_view_count, default: 0
      t.integer  :front_image_submit_count, default: 0
      t.integer  :front_image_error_count, default: 0
      t.datetime :back_image_view_at
      t.integer  :back_image_view_count, default: 0
      t.integer  :back_image_submit_count, default: 0
      t.integer  :back_image_error_count, default: 0
      t.datetime :mobile_front_image_view_at
      t.integer  :mobile_front_image_view_count, default: 0
      t.datetime :mobile_back_image_view_at
      t.integer  :mobile_back_image_view_count, default: 0
      t.datetime :ssn_view_at
      t.integer  :ssn_view_count, default: 0
      t.datetime :verify_view_at
      t.integer  :verify_view_count, default: 0
      t.integer  :verify_submit_count, default: 0
      t.integer  :verify_error_count, default: 0
      t.datetime :doc_success_view_at
      t.integer  :doc_success_view_count, default: 0
      t.datetime :verify_phone_view_at
      t.integer  :verify_phone_view_count, default: 0
      t.datetime :usps_address_view_at
      t.integer  :usps_address_view_count, default: 0
      t.datetime :usps_letter_sent_view_at
      t.integer  :usps_letter_sent_view_count, default: 0
      t.datetime :usps_address_submit_at
      t.integer  :usps_address_submit_count, default: 0
      t.integer  :usps_address_error_count, default: 0
      t.datetime :encrypt_view_at
      t.integer  :encrypt_view_count, default: 0
      t.datetime :verified_view_at
      t.integer  :verified_view_count, default: 0
      t.timestamps
    end
    add_index :doc_auth_logs, %i[user_id], unique: true
    add_index :doc_auth_logs, %i[verified_view_at]
  end
end
