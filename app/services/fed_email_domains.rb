class FedEmailDomains
  FED_EMAIL_DOMAINS_PATH = Rails.root.join(IdentityConfig.store.fed_domain_file_path).freeze

  def self.email_is_fed_domain(domain)
    email&.split('@')&.last
  end
end
  