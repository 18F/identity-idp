class UspsConfirmationMaker
  def initialize(pii:, issuer:)
    @pii = pii
    @issuer = issuer
  end

  def perform
    entry = UspsConfirmationEntry.new_from_hash(attributes)
    UspsConfirmation.create!(entry: entry.encrypted)
  end

  private

  attr_reader :pii, :issuer

  # rubocop:disable AbcSize, MethodLength
  # This method is single statement spread across many lines for readability
  def attributes
    {
      address1: pii[:address1],
      address2: pii[:address2],
      city: pii[:city],
      otp: pii[:otp],
      first_name: pii[:first_name],
      last_name: pii[:last_name],
      state: pii[:state],
      zipcode: pii[:zipcode],
      issuer: issuer,
    }
  end
  # rubocop:enable AbcSize, MethodLength
end
