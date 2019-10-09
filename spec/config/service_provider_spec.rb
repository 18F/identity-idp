require 'rails_helper'

file = Rails.root.join('config', 'service_providers.yml').read
content = ERB.new(file).result
prod_sp_config = YAML.safe_load(content).fetch('production', {})

describe 'sp config yaml' do
  it 'should be parsable yaml' do
    expect(prod_sp_config.length).to be > 0
  end

  prod_sp_config.each do |sp|
    issuer = sp.first
    config = sp.last
    describe "#{issuer}" do
      describe 'cert' do
        let(:cert) {OpenSSL::X509::Certificate.new(load_cert(config['cert'])) if config['cert']}

        it 'should be present' do
          expect(config.has_key?('cert')).to be true
          expect(config['cert'].length).to be > 0
        end

        it 'should have a cert with acceptable expiry for each issuer' do
          expect(cert.not_after).to be_between(now, 6.months.from_now)
        end

        it 'should have a cert that is at least 2048 bits in length' do
        end
      end
      describe 'logo' do
        it 'should be present' do
          expect(config.has_key?('logo')).to be true
          expect(config['logo'].length).to be > 0
        end
      end

      describe 'failure to proof url' do
        it 'should have a failure_to_proof_url if service provider is IAL2' do
          expect(config.has_key?('')) if config.has_key?('ial') && config['ial'] == 2
        end
      end

      describe 'SAML service provider' do
        it 'should have an acs_url' do
          expect(config.has_key?('acs_url')).to be true
          expect(config['acs_url'].length).to be > 0
        end
        it 'should have an assertion_consumer_logout_service_url' do
          expect(config.has_key?('assertion_consumer_logout_service_url')).to be true
          expect(config['assertion_consumer_logout_service_url'].length).to be > 0
        end

      end

      describe 'OIDC service provider' do
        it 'should have an acs_url' do

        end
        it 'should have an assertion_consumer_logout_service_url' do

        end

        it 'should have a sp_initiated_login_url' do

        end
      end
    end
  end

end
