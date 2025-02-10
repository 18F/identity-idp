# frozen_string_literal: true

class DisposableEmailDomain < ApplicationRecord
  def self.disposable?(domain)
    exists?(name: subdomains(domain))
  end

  # @return [Array<String>]
  # @example
  #   subdomains("foo.bar.baz.com")
  #   => ["foo.bar.baz.com", "bar.baz.com", "baz.com"]
  def self.subdomains(domain)
    parts = domain.split('.')

    parts[...-1].to_enum.with_index.map do |_part, index|
      parts[index..].join('.')
    end
  end
end
