module CloudhsmMocks
  CLOUDHSM_MOCK_PRIVATE_KEY = <<~RSA.freeze
    -----BEGIN PRIVATE KEY-----
    MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDw7ABGNp20nVRO
    eu52HY+HcIJUDru6K49dZ2n8eAgoba8QWOHi8r77KNuyvCgRen40y2lbizyLvNtc
    fPrCNfQPMZGqQByWUE/+E4QVoyxikBxy30CcO/gb+w2evbVK1PpQKlX31xdtjUVP
    Hp3bxxhsoCl4w071LUEbtkJslcDh53K34ZVkNA6AjcxXbPh8V5KliPDqX9q+n1my
    ThToe2ohHXQhG3FQjFx7WL4pcIUn9B085pivECGG6fOdbW3XxjjX8Ugkl9iQMDLo
    ClhuuOwOn7MbZBzNKwakNQjOuW3y6vcpnxiWR6OFJ7ldFE5zTLFKa4enKgJmpH6g
    YbUg+FELAgMBAAECggEAYujhK/JcSLyW0imSIRf9xyMfvpbV55beowBD+QzmfIKb
    buCuzFfQpJifqf+pi5N4oQAp3xWI4+3DOXNuF7HC40H8haMQmX2bebpVbfSx0j1M
    ELUrd3j/Ya1uaA+GkJRjt+nJpZi+25E2NUdik8pncqFGpXe5wNq1ckUffCj3KUbq
    WgLsFSBqK8/9Z4ts8IvX4ZwzBwA434hBcXqAzfB465bAwbdKRCiV11Sy4hg6TIiO
    NDBgrveDzQwzLIY/mv83dJWu006HSo4aDFDKJ2heVBjiC2Avt71L9dRHW3Fn6wUc
    1kWZzLJ49+UByJHts8qRLhoLgsuEobVxkPZXAmoAAQKBgQD6/X8m0bMkJPe9iTrj
    3H0AZnLhNaULGiCweBYeJO+GEQV+OFwzVxGJnisYR1eB8pb13Ca1O5lG8nNP8hM0
    foQuOrz3v6ycLcixhT6k+A76+AoZeXaGC/IZ8e9ROW5nXwFTMljM4BMhyoj6S4Ql
    vqPadKiznNtKgckA4wGB/CrAAQKBgQD1uw6z1pD7mJegLI24fDlBrpPbf1dFPtR5
    OCA7V0bwmj+wtui510az4p2TZfWnCvCMDe3MNB04C8utxFfh1yqcuOZp/4SzZtzo
    8F112FX35XB9543EMn5dc+lMyzvO84suS40B86D5+Jk2QKnFDWjCM3MBIapjM8oz
    VOgC9GIRCwKBgQDq/kz+W3gOb05E9ydcECQ5K7KDiWZtbpkMoGKU9qAMNgOemcY5
    i1uwLZbLtIAJ+se8idLz/EkWVAoC3/N7QrkfT399tsg1seglzUtJyba8418RWtfN
    yYFzKUGYGt1zi1ACRTE/IMzI5og5UFr5u/RNpMwO3t2ydLFtUx0mRqMAAQKBgDuA
    MN4w/Wg+mbBqOWLLiZ2y5RCINByLSy2S/pL/3iiSYQusLowZaYBTRi6TyLjK+FYh
    ZUxF7jFNAeOwoEsKK8JJL1nJSluac7FfynGnkaF2CBgkgnpYc6qzT3GN4IyLAk+S
    cbFgScFdhdPSMomJZq1ngdhrS3O77aEiVQ+qFzjjAoGAcBfZLSUGqEWJehewNRNR
    uD9sxqUCEgCVJh1QGXlQ3OvImZ1LRzetTfDDhXj1XHquaZ0rFyEFkTrymTMcYwXN
    Q6IOIBKfUl6TEW6dXSq9vThjp60Yf2ffoCW09ro8QFhJe95lvnT32FzyQry0LYba
    cWarcJInkleenOSonOxG5lc=
    -----END PRIVATE KEY-----
  RSA

  class MockSession
    include RSpec::Matchers

    def login(context, pin)
      expect(context).to eq(:USER)
      expect(pin).to eq('user:password')
    end

    def logout; end

    def find_objects(options)
      expect(options[:LABEL]).to eq('key1')
      [:hsm_key]
    end

    def sign(algorithm, key, raw)
      expect(algorithm).to eq(:SHA256_RSA_PKCS)
      expect(key).to eq(:hsm_key)
      key = OpenSSL::PKey::RSA.new(CLOUDHSM_MOCK_PRIVATE_KEY)
      key.sign(OpenSSL::Digest::SHA256.new, raw)
    end
  end

  def cloudhsm_mock_session
    @cloudhsm_mock_session ||= MockSession.new
  end

  def mock_cloudhsm
    allow(FeatureManagement).to receive(:use_cloudhsm?).and_return(true)
    allow(SamlIdp.config).to receive(:cloudhsm_enabled).and_return(true)
    allow(SamlIdp.config).to receive_message_chain(:pkcs11, :active_slots, :first, :open).
      and_yield(cloudhsm_mock_session)
  end
end
