module WebauthnVerificationHelper
  def protocol
    'http://'
  end

  def challenge
    [152, 207, 129, 117, 183, 199, 18, 19, 51, 104, 207, 109, 12, 50, 143, 155]
  end

  def credential_ids
    '60Aa7rKEJJEkqDM0flq4NoNu3L/ZpZfamNbScSG+I9AZnV3efKCyRNXK78lRxuqmxmfa87fwrrS1+5PJvJdG0A=='
  end

  def credential_id
    '60Aa7rKEJJEkqDM0flq4NoNu3L/ZpZfamNbScSG+I9AZnV3efKCyRNXK78lRxuqmxmfa87fwrrS1+5PJvJdG0A=='
  end

  def authenticator_data
    'SZYN5YgOjGh0NBcPZHZgW4/krrmihjLHmVzzuoMdl2MBAAAAJg=='
  end

  def signature
    'MEUCIQDlEB4VUN/X15N/Jmgx4ACbOlLLHRRcKsBkejpdQj81vQIgIo97sxdpP/hZgQpIXJMa3cBnAzcnfw+1CJ2LP3VvOg\
4='
  end

  def client_data_json
    'eyJjaGFsbGVuZ2UiOiJtTS1CZGJmSEVoTXphTTl0RERLUG13Iiwib3JpZ2luIjoiaHR0cDovL2xvY2FsaG9zdDozMDAwI\
iwidHlwZSI6IndlYmF1dGhuLmdldCJ9'
  end

  def public_key
    'BBWEWPFKW60xPIcf/U098QEsiB3wUmJm9TN+bU1d5Y9noAnfr412Wu3KOrX0uhy/t14t4aFuUfNu054zkKVhQDM='
  end

  def create_webauthn_configuration(user)
    WebauthnConfiguration.create(
      user_id: user.id,
      credential_id: credential_id,
      credential_public_key: public_key,
      name: 'foo',
    )
  end
end
