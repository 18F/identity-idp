# frozen_string_literal: true

class FedEmailDomain < ApplicationRecord
  def self.fed_domain?(domain)
    exists?(name: domain)
  end
end
  