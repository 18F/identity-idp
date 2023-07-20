module Idv::Engine::Payloads
  # Event payload that holds a Social Security Number (SSN).
  class Ssn
    include ActiveModel::Model
    attr_accessor :ssn
  end
end
