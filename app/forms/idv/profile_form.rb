module Idv
  class ProfileForm
    include ActiveModel::Model

    attr_reader :user

    def self.model_name
      ActiveModel::Name.new(self, nil, 'Profile')
    end

    validates :first_name, :last_name, :dob, :ssn,
              :address1, :city, :state, :zipcode, presence: true

    validate :ssn_is_unique, :dob_is_sane

    validates_format_of :zipcode,
                        with: /\A\d{5}(-?\d{4})?\z/,
                        message: I18n.t('idv.errors.pattern_mismatch.zipcode'),
                        allow_blank: true
    validates_format_of :ssn,
                        with: /\A\d{3}-?\d{2}-?\d{4}\z/,
                        message: I18n.t('idv.errors.pattern_mismatch.ssn'),
                        allow_blank: true

    delegate :user_id, :first_name, :last_name, :phone, :email, :dob, :ssn, :address1,
             :address2, :city, :state, :zipcode, to: :pii_attributes

    def initialize(params, user)
      @user = user
      initialize_params(params)
    end

    def profile
      @profile ||= Profile.new
    end

    def pii_attributes
      @_pii_attributes ||= Pii::Attributes.new
    end

    def submit(params)
      params.each { |key, val| pii_attributes[key] = val }
      profile.ssn_signature = ssn_signature
      @success = valid?
      result
    end

    private

    attr_writer :first_name, :last_name, :phone, :email, :dob, :ssn, :address1,
                :address2, :city, :state, :zipcode

    attr_reader :success

    def initialize_params(params)
      params.each do |key, value|
        next unless Pii::Attributes.members.include?(key.to_sym)
        pii_attributes[key] = value
      end
    end

    def ssn_signature(key = Pii::Fingerprinter.current_key)
      Pii::Fingerprinter.fingerprint(ssn, key) if ssn
    end

    def ssn_is_unique
      errors.add :ssn, I18n.t('idv.errors.duplicate_ssn') if ssn_is_duplicate?
    end

    def ssn_is_duplicate?
      return true if any_matching_ssn_signatures?(ssn_signature)
      return true if ssn_is_duplicate_with_old_key?
    end

    def ssn_is_duplicate_with_old_key?
      signatures = KeyRotator::Utils.old_keys(:hmac_fingerprinter_key_queue).map do |key|
        ssn_signature(key)
      end
      any_matching_ssn_signatures?(signatures)
    end

    def any_matching_ssn_signatures?(signatures)
      Profile.where.not(user_id: @user.id).where(ssn_signature: signatures).any?
    end

    def dob_is_sane
      date = parsed_dob

      return if date && dob_in_the_past?(date)

      errors.set :dob, [I18n.t('idv.errors.bad_dob')]
    end

    def dob_in_the_past?(date)
      date < Time.zone.today
    end

    def parsed_dob
      Date.parse(dob.to_s)
    rescue
      nil
    end

    def result
      {
        success: success,
        errors: errors.messages
      }
    end
  end
end
