# frozen_string_literal: true

# Represents a record of a phone number that has been opted out of SMS in AWS Pinpoint
# AWS maintains separate opt-out lists per region, so this helps us keep track across regions
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
