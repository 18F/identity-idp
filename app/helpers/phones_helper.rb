module PhonesHelper
  def can_add_phone?
    current_user.phone_configurations.count < IdentityConfig.store.max_phone_numbers_per_account
  end
end
