module Idv
  class ProfileForm
    include ActiveModel::Model

    attr_reader :user

    def self.model_name
      ActiveModel::Name.new(self, nil, 'Profile')
    end

    validates :address1, :city, :dob, :first_name, :last_name, :ssn, :state, :zipcode,
              presence: true

    validate :dob_is_sane, :ssn_is_unique

    validates_format_of :zipcode,
                        with: /\A\d{5}(-?\d{4})?\z/,
                        message: I18n.t('idv.errors.pattern_mismatch.zipcode'),
                        allow_blank: true
    validates_format_of :ssn,
                        with: /\A\d{3}-?\d{2}-?\d{4}\z/,
                        message: I18n.t('idv.errors.pattern_mismatch.ssn'),
                        allow_blank: true

    delegate(*Pii::Attributes.members, :user_id, to: :pii_attributes)

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
      initialize_params(params)
      profile.ssn_signature = ssn_signature

      FormResponse.new(success: valid?, errors: errors.messages)
    end

    def duplicate_ssn?
      return true if any_matching_ssn_signatures?(ssn_signature)
      return true if ssn_is_duplicate_with_old_key?
    end

    private

    attr_writer(*Pii::Attributes.members)
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
      errors.add :ssn, I18n.t('idv.errors.duplicate_ssn') if duplicate_ssn?
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
  end
end
