module Agreements
  class IaaBlueprint < Blueprinter::Base
    identifier :iaa_number

    field :partner_account
    field :gtc_number
    field :gtc_mod_number
    field :gtc_start_date, datetime_format: '%Y-%m-%d'
    field :gtc_end_date, datetime_format: '%Y-%m-%d'
    field :gtc_estimated_amount
    field :gtc_status
    field :order_number
    field :order_mod_number
    field :order_start_date, datetime_format: '%Y-%m-%d'
    field :order_end_date, datetime_format: '%Y-%m-%d'
    field :order_estimated_amount
    field :order_status
  end
end
