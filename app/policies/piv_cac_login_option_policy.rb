class PivCacLoginOptionPolicy
  def initialize(user)
    @user = user
  end

  def configured?
    FeatureManagement.piv_cac_enabled? && user.x509_dn_uuid.present?
  end

  private

  attr_reader :user
end
