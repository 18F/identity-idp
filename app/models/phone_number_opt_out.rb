class PhoneNumberOptOut < ApplicationRecord
  include NonNullUuid
  include EncryptableAttribute

  encrypted_attribute(name: :phone)

  # @return [PhoneNumberOptOut, nil]
  def self.find_with_phone(phone_number)
    normalized = normalize(phone_number)

    find_by(
      phone_fingerprint: [
        Pii::Fingerprinter.fingerprint(normalized),
        *Pii::Fingerprinter.previous_fingerprints(normalized),
      ],
    )
  end

  # @return [PhoneNumberOptOut]
  def self.create_or_find_with_phone(phone_number)
    normalized = normalize(phone_number)
    create_or_find_by!(phone_fingerprint: Pii::Fingerprinter.fingerprint(normalized)).tap do |row|
      if row.encrypted_phone.blank?
        row.phone = normalized
        row.save!
      end
    end
  end

  class << self
    alias_method :mark_opted_out, :create_or_find_with_phone
  end

  def self.from_param(uuid)
    find_by!(uuid: uuid)
  end

  def formatted_phone
    self.class.normalize(phone)
  end

  def opt_in
    destroy
  end

  def to_param
    uuid
  end

  def self.normalize(phone)
    Phonelib.parse(phone).international
  end
end

# rubocop:disable Layout/LineLength
# == Schema Information
#
# Table name: phone_number_opt_outs
#
#  id                :bigint           not null, primary key
#  encrypted_phone   :string
#  phone_fingerprint :string           not null
#  uuid              :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
# Indexes
#
#  index_phone_number_opt_outs_on_phone_fingerprint  (phone_fingerprint) UNIQUE
#  index_phone_number_opt_outs_on_uuid               (uuid) UNIQUE
#
# rubocop:enable Layout/LineLength
