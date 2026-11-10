# frozen_string_literal: true

class AddDirectOtpPhoneFingerprintToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :direct_otp_phone_fingerprint, :string, comment: 'sensitive=true'
  end
end
