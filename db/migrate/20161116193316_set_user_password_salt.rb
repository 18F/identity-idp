class SetUserPasswordSalt < ActiveRecord::Migration
  def change
    User.where('password_salt IS NULL').find_each do |u|
      u.update!(password_salt: Devise.friendly_token[0, 20])
    end
  end
end
