class GpoConfirmationMaker
  def initialize(pii:, service_provider:, profile: nil, profile_id: nil, otp: nil)
    raise ArgumentError 'must have either profile or profile_id' if !profile && !profile_id

    @pii = pii
    @service_provider = service_provider
    @profile = profile
    @profile_id = profile_id
    @otp = otp
  end

  def otp
    @otp ||= generate_otp
  end

  def perform
    GpoConfirmation.create!(entry: attributes)
    GpoConfirmationCode.create!(
      profile_id: profile&.id || profile_id,
      otp_fingerprint: Pii::Fingerprinter.fingerprint(otp),
    )

    update_proofing_cost
  end

  private

  attr_reader :pii, :service_provider, :profile, :profile_id

  def attributes
    {
      address1: pii[:address1],
      address2: pii[:address2],
      city: pii[:city],
      otp: otp,
      first_name: pii[:first_name],
      last_name: pii[:last_name],
      state: pii[:state],
      zipcode: force_zipcode_format(pii[:zipcode]),
      issuer: service_provider&.issuer,
    }
  end

  def generate_otp
    ProfanityDetector.without_profanity do
      # Crockford encoding is 5 bits per character
      Base32::Crockford.encode(SecureRandom.random_number(2 ** (5 * 10)), length: 10)
    end
  end

  def update_proofing_cost
    Db::ProofingCost::AddUserProofingCost.call(profile&.user&.id, :gpo_letter)
    Db::SpCost::AddSpCost.call(service_provider, 2, :gpo_letter)
  end

  def force_zipcode_format(raw_zipcode)
    return raw_zipcode if raw_zipcode.nil?
    return raw_zipcode if raw_zipcode.match?(/^\d{5}$/)
    return raw_zipcode if raw_zipcode.match?(/^\d{5}-\d{4}$/)

    return raw_zipcode[0..4]
  end
end
