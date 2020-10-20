class TestCipherController < ApplicationController
  include Encryption::Encodable

  skip_before_action :verify_authenticity_token

  def show
    # puts 'TestCipherController#show'
  end
  
  def update
    # puts 'TestCipherController#update'
    # puts "\npayload: "
    # pp payload
    # puts
    key = decode(params[:key])
    plaintext = Encryption::AesCipher.new.decrypt(payload, key)
    # puts "\nplaintext = #{plaintext}\n"
    render json: { deciphered: plaintext }
  end
  
  def payload
    return @result if defined? result
    
    raw_ciphertext = decode(params[:ciphertext])
    raw_tag = raw_ciphertext.slice!(-16, decode(params[:key]).length)
    tag = encode(raw_tag)
    ciphertext = encode(raw_ciphertext)

    @result = {
      iv: params[:iv],
      tag: encode(raw_tag),
      ciphertext: encode(raw_ciphertext),
    }.to_json
  end
end