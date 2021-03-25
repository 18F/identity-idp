module Agreements
  class PartnerAccountBlueprint < Blueprinter::Base
    identifier :requesting_agency

    field :name
    field :became_partner, datetime_format: "%Y-%m-%d"
    field :status do |account, _options|
      account.partner_status
    end
  end
end
