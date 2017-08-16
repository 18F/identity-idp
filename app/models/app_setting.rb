class AppSetting < ApplicationRecord
  validates :name, presence: true, uniqueness: true

  validates :value,
            inclusion: { in: %w[0 1], message: :invalid },
            presence: true, if: :boolean?

  def self.registrations_enabled?
    find_by(name: 'RegistrationsEnabled').try(:value) == '1'
  end

  def self.registrations_disabled?
    !registrations_enabled?
  end

  def boolean?
    name =~ /RegistrationsEnabled/
  end
end
