class Profile < ActiveRecord::Base
  belongs_to :user

  validates :active, uniqueness: { scope: :user_id, if: :active? }
  validates :ssn_signature, uniqueness: { scope: :active, if: :active? }

  scope :active, -> { where(active: true) }
  scope :verified, -> { where.not(verified_at: nil) }

  def self.create_with_encrypted_pii(user, plain_pii, password)
    profile = new(user: user)
    profile.encrypt_pii(password, plain_pii)
    profile.save!
    profile
  end

  def activate
    transaction do
      Profile.where('user_id=?', user_id).update_all(active: false)
      update!(active: true, activated_at: Time.zone.now)
    end
  end

  def plain_pii
    @_plain_pii ||= Pii::Attributes.new
  end

  def decrypt_pii(password)
    Pii::Attributes.new_from_encrypted(encrypted_pii, password)
  end

  def encrypt_pii(password, pii = plain_pii)
    ssn = pii.ssn
    encryptor = Pii::Encryptor.new
    self.ssn_signature = Digest::SHA256.hexdigest(encryptor.sign(ssn)) if ssn
    self.encrypted_pii = pii.encrypted(password)
  end

  def method_missing(method_sym, *arguments, &block)
    attr_name_sym = method_sym.to_s.gsub(/=\z/, '').to_sym
    if plain_pii.members.include?(attr_name_sym)
      return plain_pii[attr_name_sym] if arguments.empty?
      plain_pii[attr_name_sym] = arguments.first
    else
      super
    end
  end

  def respond_to_missing?(method_sym, include_private)
    attr_name_sym = method_sym.to_s.gsub(/=\z/, '').to_sym
    plain_pii.members.include?(attr_name_sym) || super
  end
end
