# == Schema Information
#
# Table name: integration_statuses
#
#  id           :bigint           not null, primary key
#  name         :string           not null
#  order        :integer          not null
#  partner_name :string
#
# Indexes
#
#  index_integration_statuses_on_name   (name) UNIQUE
#  index_integration_statuses_on_order  (order) UNIQUE
#
class Agreements::IntegrationStatus < ApplicationRecord
  self.table_name = 'integration_statuses'

  has_many :integrations, dependent: :restrict_with_exception

  validates :name, presence: true, uniqueness: true
  validates :order, presence: true,
                    uniqueness: true,
                    numericality: { only_integer: true }
end
