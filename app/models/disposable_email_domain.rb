class DisposableEmailDomain < ApplicationRecord
  def self.disposable?(domain)
    exists?(name: domain)
  end
end
