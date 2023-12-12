class DisposableDomain < ApplicationRecord
  class << self
    def disposable?(domain)
      return false if !domain.is_a?(String) || domain.empty?

      exists?(name: domain)
    end
  end
end
