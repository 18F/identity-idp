module FormPasswordValidator
  extend ActiveSupport::Concern

  included do
    validates :password,
              presence: true,
              length: Devise.password_length
  end
end
