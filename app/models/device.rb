class Device < ApplicationRecord
  belongs_to :user
  has_many :device_events, dependent: :destroy
  attr_accessor :nice_name

  def decorate
    DeviceDecorator.new(self)
  end
end
