module Idv
  class ProfileForm
    include ActiveModel::Model

    def self.model_name
      ActiveModel::Name.new(self, nil, 'Profile')
    end

    validates :first_name, :last_name, :dob, :ssn,
              :address1, :city, :state, :zipcode, presence: true

    validate :ssn_is_unique

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
      valid?
    end

    private

    attr_writer :first_name, :last_name, :phone, :email, :dob, :ssn, :address1,
                :address2, :city, :state, :zipcode

    def ssn_is_unique
      if Profile.where.not(user_id: @user.id).where(ssn: ssn).any?
        errors.add :ssn, I18n.t('idv.errors.duplicate_ssn')
      end
    end
  end
end
