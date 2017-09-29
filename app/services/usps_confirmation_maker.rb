class UspsConfirmationMaker
  def initialize(pii:, issuer:, profile:)
    @pii = pii
    @issuer = issuer
    @profile = profile
  end

  def otp
    @otp ||= generate_otp
  end

  def perform
    entry = UspsConfirmationEntry.new_from_hash(attributes)
    UspsConfirmation.create!(entry: entry.encrypted)
    UspsConfirmationCode.create!(
      profile: profile,
      otp_fingerprint: Pii::Fingerprinter.fingerprint(otp)
    )
  end

  private

  attr_reader :pii, :issuer, :profile

  # rubocop:disable AbcSize, MethodLength
  # This method is single statement spread across many lines for readability
  def attributes
    {
      address1: pii[:address1].norm,
      address2: pii[:address2].norm,
      city: pii[:city].norm,
      otp: otp,
      first_name: pii[:first_name].norm,
      last_name: pii[:last_name].norm,
      state: pii[:state].norm,
      zipcode: pii[:zipcode].norm,
      issuer: issuer,
    }
  end
  # rubocop:enable AbcSize, MethodLength

  def generate_otp
    # Crockford encoding is 5 bits per character
    Base32::Crockford.encode(SecureRandom.random_number(2**(5 * 10)), length: 10)
  end
end
