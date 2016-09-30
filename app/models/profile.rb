class Profile < ActiveRecord::Base
  belongs_to :user

  validates :active, uniqueness: { scope: :user_id, if: :active? }
  validates :ssn_signature, uniqueness: { scope: :active, if: :active? }

  scope :active, -> { where(active: true) }
  scope :verified, -> { where.not(verified_at: nil) }

  def self.create_from_proofer_applicant(applicant, user, password)
    profile = new(user: user)
    profile.encrypt_pii(password, pii_from_applicant(applicant))
    profile.save!
    profile
  end

  def activate
    transaction do
      Profile.where('user_id=?', user_id).update_all(active: false)
      update!(active: true, activated_at: Time.zone.now)
    end
  end

  def verified?
    verified_at.present?
  end

  def decrypt_pii(password)
    pii_json = encryptor.decrypt(encrypted_pii, password)
    self.class.inflate_pii_json(pii_json)
  end

  def encrypt_pii(password, pii = plain_pii)
    ssn = pii.ssn
    self.ssn_signature = Digest::SHA256.hexdigest(encryptor.sign(ssn)) if ssn
    self.encrypted_pii = encryptor.encrypt(pii.to_json, password)
  end

  def plain_pii
    @_plain_pii ||= Pii::Attributes.new
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

  def self.inflate_pii_json(pii_json)
    pii_attrs = Pii::Attributes.new
    return pii_attrs unless pii_json.present?
    pii = JSON.parse(pii_json, symbolize_names: true)
    pii.keys.each { |attr| pii_attrs[attr] = pii[attr] }
    pii_attrs
  end

  def encryptor
    @_encryptor ||= Pii::Encryptor.new
  end

  # rubocop:disable MethodLength
  # This method is single statement spread across many lines for readability
  def self.pii_from_applicant(applicant)
    Pii::Attributes.new_from_hash(
      first_name: applicant.first_name,
      middle_name: applicant.middle_name,
      last_name: applicant.last_name,
      address1: applicant.address1,
      address2: applicant.address2,
      city: applicant.city,
      state: applicant.state,
      zipcode: applicant.zipcode,
      dob: applicant.dob,
      ssn: applicant.ssn,
      phone: applicant.phone
    )
  end
  # rubocop:enable MethodLength

  private_class_method :pii_from_applicant
end
