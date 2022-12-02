# == Schema Information
#
# Table name: monthly_auth_counts
#
#  id         :bigint           not null, primary key
#  auth_count :integer          default(1), not null
#  issuer     :string           not null
#  year_month :string           not null
#  user_id    :integer          not null
#
# Indexes
#
#  index_monthly_auth_counts_on_issuer_and_year_month_and_user_id  (issuer,year_month,user_id) UNIQUE
#
class MonthlyAuthCount < ApplicationRecord
end
