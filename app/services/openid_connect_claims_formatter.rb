# frozen_string_literal: true

# Formats a person's decrypted identity attributes as OpenID Connect claims, in the shape the
# userinfo endpoint has always presented them: `address` as the OpenID Connect Core §5.1.1
# address claim, `phone` in E.164, `birthdate` as an ISO 8601 date, `postal_code` cut to five
# digits, and PIV/CAC certificate facts as the `x509_*` claims.
#
# Userinfo and delegated-token introspection both format through this class, so an agency reads
# one claim shape whether the person signed in directly or a service provider is acting for them.
class OpenidConnectClaimsFormatter
  # @param pii [Pii::Attributes, nil] decrypted profile attributes; nil or empty formats to nils
  # @param x509 [X509::Attributes, nil] PIV/CAC certificate attributes
  def initialize(pii: nil, x509: nil)
    @pii = pii || Pii::Attributes.new_from_hash({})
    @x509 = x509 || X509::Attributes.new_from_hash({})
  end

  def identity_proofing_claims
    {
      given_name: stringify_attr(pii.first_name),
      family_name: stringify_attr(pii.last_name),
      birthdate: dob,
      social_security_number: stringify_attr(pii.ssn),
      address: address,
      phone: phone,
      phone_verified: phone.present? || nil,
    }
  end

  def x509_claims
    {
      x509_subject: stringify_attr(x509.subject),
      x509_issuer: stringify_attr(x509.issuer),
      x509_presented: !!x509.presented.raw,
    }
  end

  private

  attr_reader :pii, :x509

  def phone
    return if pii.phone.blank?

    Phonelib.parse(pii.phone).e164
  end

  def dob
    return if pii.dob.blank?

    DateParser.parse_legacy(pii.dob).to_s
  end

  def address
    return nil if pii.address1.blank?

    {
      formatted: formatted_address,
      street_address: street_address,
      locality: stringify_attr(pii.city),
      region: stringify_attr(pii.state),
      postal_code: postal_code,
    }
  end

  def formatted_address
    [
      street_address,
      "#{pii.city}, #{pii.state} #{postal_code}",
    ].compact.join("\n")
  end

  def postal_code
    stringify_attr(pii.zipcode)&.strip&.slice(0, 5)
  end

  def street_address
    [pii.address1, pii.address2].compact.join("\n")
  end

  def stringify_attr(attribute)
    attribute.to_s.presence
  end
end
