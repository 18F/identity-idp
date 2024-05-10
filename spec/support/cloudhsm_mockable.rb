require_relative 'certificate_helpers'

module CloudhsmMockable
  class MockSession
    include CertificateHelpers
    include RSpec::Matchers

    def login(context, pin)
      expect(context).to eq(:USER)
      expect(pin).to eq(1234)
    end

    def logout; end

    def find_objects(options)
      expect(options[:LABEL]).to eq('secret')
      [:hsm_key]
    end

    def sign(algorithm, key, raw)
      expect(algorithm).to eq(:SHA256_RSA_PKCS)
      expect(key).to eq(:hsm_key)
      key = OpenSSL::PKey::RSA.new(cloudhsm_idp_secret_key)
      key.sign(OpenSSL::Digest.new('SHA1'), raw)
    end
  end

  def cloudhsm_session
    @cloudhsm_session ||= MockSession.new
  end

  def mock_cloudhsm
    allow(SamlIdp.config).to receive(:cloudhsm_enabled).and_return(true)
    allow(SamlIdp.config).to receive_message_chain(:pkcs11, :active_slots, :first, :open).
      and_yield(cloudhsm_session)
    allow(SamlIdp.config).to receive(:cloudhsm_pin).and_return(1234)
  end
end
