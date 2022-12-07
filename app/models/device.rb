class Device < ApplicationRecord
  belongs_to :user
  # rubocop:disable Rails/HasManyOrHasOneDependent
  has_many :events # we are retaining events after delete
  # rubocop:enable Rails/HasManyOrHasOneDependent
  attr_accessor :nice_name
  validates :user_id, presence: true
  validates :cookie_uuid, presence: true
  validates :last_used_at, presence: true
  validates :last_ip, presence: true

  def decorate
    DeviceDecorator.new(self)
  end

  # @return [Device]
  def update_last_used_ip(remote_ip, now: Time.zone.now)
    self.last_used_at = now
    self.last_ip = remote_ip
    save
    self
  end
end

# == Schema Information
#
# Table name: devices
#
#  id           :bigint           not null, primary key
#  cookie_uuid  :string           not null
#  last_ip      :string(255)      not null
#  last_used_at :datetime         not null
#  user_agent   :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  user_id      :integer          not null
#
# Indexes
#
#  index_device_user_id_last_used_at  (user_id,last_used_at)
#  index_devices_on_cookie_uuid       (cookie_uuid)
#
