class Profile < ActiveRecord::Base
  belongs_to :user

  validates :active, uniqueness: { scope: :user_id, if: :active? }

  scope :active, -> { where(active: true) }
  scope :verified, -> { where.not(verified_at: nil) }

  before_save :encrypt_pii

  VALID_PII_ATTRIBUTES = [
    :first_name, :middle_name, :last_name, :address1, :address2, :city, :state, :zipcode,
    :ssn, :dob, :phone
  ].freeze

  def self.create_from_proofer_applicant(applicant, user)
    pii = pii_from_applicant(applicant)
    create(user: user, encrypted_pii: pii)
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

  def decrypted_pii
    @_decrypted_pii ||= inflate_pii(encrypted_pii)
  end

  def method_missing(method_sym, *arguments, &block)
    attr_name_sym = method_sym.to_s.gsub(/=\z/, '').to_sym
    if VALID_PII_ATTRIBUTES.include?(attr_name_sym)
      return decrypted_pii[attr_name_sym] if arguments.empty?
      decrypted_pii[attr_name_sym] = arguments.first
    else
      super
    end
  end

  def respond_to_missing?(method_sym, include_private)
    attr_name_sym = method_sym.to_s.gsub(/=\z/, '').to_sym
    VALID_PII_ATTRIBUTES.include?(attr_name_sym) || super
  end

  private

  def encrypt_pii
    return unless @_decrypted_pii
    self.encrypted_pii = decrypted_pii.to_json
  end

  def inflate_pii(pii)
    return {} unless pii.present?
    JSON.parse(pii, symbolize_names: true)
  end

  # rubocop:disable MethodLength
  # This method is single statement spread across many lines for readability
  def self.pii_from_applicant(applicant)
    {
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
    }.to_json
  end
  # rubocop:enable MethodLength

  private_class_method :pii_from_applicant
end
