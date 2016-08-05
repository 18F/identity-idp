class IdvProfileForm
  include ActiveModel::Model

  def self.model_name
    ActiveModel::Name.new(self, nil, 'Profile')
  end

  validates :first_name, :last_name, :dob, :ssn, :address1, :city, :state, :zipcode, presence: true

  validate :ssn_is_unique

  delegate :user_id, :first_name, :last_name, :phone, :email, :dob, :ssn, :address1,
           :address2, :city, :state, :zipcode, to: :profile

  def profile
    @profile ||= Profile.new
  end

  def submit(params, user_id)
    @user_id = user_id
    @ssn = params[:ssn]
    profile.attributes = params
    valid?
  end

  private

  attr_writer :first_name, :last_name, :phone, :email, :dob, :ssn, :address1,
              :address2, :city, :state, :zipcode

  def ssn_is_unique
    if Profile.where.not(user_id: @user_id).where(ssn: @ssn).any?
      errors.add :ssn, I18n.t('idv.errors.duplicate_ssn')
    end
  end
end
