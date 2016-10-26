class Profile < ActiveRecord::Base
  belongs_to :user

  validates :active, uniqueness: { scope: :user_id, if: :active? }
  validates :ssn_signature, uniqueness: { scope: :active, if: :active? }

  scope :active, -> { where(active: true) }
  scope :verified, -> { where.not(verified_at: nil) }

  def activate
    transaction do
      Profile.where('user_id=?', user_id).update_all(active: false)
      update!(active: true, activated_at: Time.zone.now)
    end
  end

  def decrypt_pii(password)
    Pii::Attributes.new_from_encrypted(encrypted_pii, password, salt)
  end

  def encrypt_pii(password, pii)
    ssn = pii.ssn
    self.ssn_signature = Pii::Fingerprinter.fingerprint(ssn) if ssn
    self.encrypted_pii = pii.encrypted(password, salt)
  end

  private

  def salt
    Pii::Fingerprinter.fingerprint(ssn_signature.to_s + user.uuid.to_s)
  end
end
