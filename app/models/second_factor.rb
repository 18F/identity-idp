class SecondFactor < ActiveRecord::Base
  # has_many :users
  has_and_belongs_to_many :users
  validates :name, uniqueness: true

  def create_authorization(user)
    return if user && user.second_factor_locked?

    "#{name}SecondFactor".constantize.transmit(user)
  end

  def self.mobile_id
    find_by_name('Mobile').id
  end
end
