# == Schema Information
#
# Table name: partner_account_statuses
#
#  id           :bigint           not null, primary key
#  name         :string           not null
#  order        :integer          not null
#  partner_name :string
#
# Indexes
#
#  index_partner_account_statuses_on_name   (name) UNIQUE
#  index_partner_account_statuses_on_order  (order) UNIQUE
#
class Agreements::PartnerAccountStatus < ApplicationRecord
  self.table_name = 'partner_account_statuses'

  has_many :partner_accounts, dependent: :restrict_with_exception

  validates :name, presence: true, uniqueness: true
  validates :order, presence: true,
                    uniqueness: true,
                    numericality: { only_integer: true }

  def partner_name
    super || name
  end
end
