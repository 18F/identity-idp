# frozen_string_literal: true

module PivCacFormHelpers
  extend ActiveSupport::Concern

  def valid_token?
    return false unless token.present?

    token_decoded &&
      token_has_correct_nonce &&
      not_error_token
  end

  def token_decoded
    @data = PivCacService.decode_token(token)
    true
  end

  def not_error_token
    possible_error = @data['error']
    if possible_error
      self.error_type = possible_error
      self.key_id = @data['key_id']
      false
    else
      self.x509_dn_uuid = @data['uuid']
      self.x509_dn = @data['subject']
      self.x509_issuer = @data['issuer']
      true
    end
  end

  def token_has_correct_nonce
    if @data['nonce'] == nonce
      true
    else
      self.error_type = 'token.invalid'
      self.key_id = @data['key_id']
      false
    end
  end
end
