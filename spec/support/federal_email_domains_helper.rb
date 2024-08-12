module FederalEmailDomainHelper
  def default_federal_domains
    FederalEmailDomain.create(name: 'gsa.gov')
    FederalEmailDomain.create(name: 'cbp.dhs.gov')
  end
end
