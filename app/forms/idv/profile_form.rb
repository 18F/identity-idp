module Idv
  class ProfileForm
    include ActiveModel::Model

    def self.model_name
      ActiveModel::Name.new(self, nil, 'Profile')
    end

    validates :first_name, :last_name, :dob, :ssn,
              :address1, :city, :state, :zipcode, presence: true

    validate :ssn_is_unique, :dob_is_sane

    delegate :user_id, :first_name, :last_name, :phone, :email, :dob, :ssn, :address1,
             :address2, :city, :state, :zipcode, to: :profile

    def initialize(params, user)
      @user = user
      profile.attributes = params.select { |key, _val| respond_to?(key.to_sym) }
    end

    def profile
      @profile ||= Profile.new
    end

    def submit(params)
      profile.assign_attributes(params)
      profile.ssn_signature = ssn_signature
      valid?
    end

    private

    attr_writer :first_name, :last_name, :phone, :email, :dob, :ssn, :address1,
                :address2, :city, :state, :zipcode

    def encryptor
      @_encryptor ||= Pii::Encryptor.new
    end

    def ssn_signature
      encryptor.sign(ssn) if ssn
    end

    def ssn_is_unique
      if Profile.where.not(user_id: @user.id).where(ssn_signature: ssn_signature).any?
        errors.add :ssn, I18n.t('idv.errors.duplicate_ssn')
      end
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
