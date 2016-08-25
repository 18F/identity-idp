class ServiceProviderConfig
  def initialize(filename:, issuer:)
    @issuer = issuer
    @data = YAML.load_file("#{Rails.root}/config/#{filename}")
  end

  def sp_attributes
    data_hash['valid_hosts'].fetch(issuer, {}).symbolize_keys
  end

  private

  attr_reader :data, :issuer

  def data_hash
    if Figaro.env.domain_name == 'superb.legit.domain.gov'
      data.merge!(data.fetch('superb.legit.domain.gov', {}))
    else
      data.merge!(data.fetch(Rails.env, {}))
    end
  end
end
