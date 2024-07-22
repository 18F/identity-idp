# frozen_string_literal: true

class FedEmailDomains
  FED_EMAIL_DOMAINS_PATH = Rails.root.join(IdentityConfig.store.fed_domain_file_path).freeze

  def self.email_is_fed_domain?(domain)
    (File.read(FED_EMAIL_DOMAINS_PATH).scan(/#{domain}/)).present?
  end
end
