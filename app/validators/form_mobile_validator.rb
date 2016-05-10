module FormMobileValidator
  extend ActiveSupport::Concern

  included do
    validate :mobile_is_unique

    validates_plausible_phone :mobile,
                              country_code: 'US',
                              presence: true,
                              message: :improbable_phone
  end

  private

  def mobile_is_unique
    return if mobile.nil? || mobile == @user.mobile

    errors.add(:mobile, :taken) if User.exists?(mobile: mobile)
  end
end
