class TestCipherController < ApplicationController
  include Encryption::Encodable

  skip_before_action :verify_authenticity_token

  def show
    puts 'TestCipherController#show'
  end
  
  def update
    puts 'TestCipherController#update'
    puts "\npayload: "
    pp payload
    puts
    key = decode(params[:key])
    # key = pack_it(params[:key])
    @plaintext = Encryption::AesCipher.new.decrypt(payload, key)
    puts "\nplaintext = #{@plaintext}\n"
    render json: { deciphered: @plaintext }
  end
  
  def payload
    return @result if defined? result
    
    # raw_iv = decode(params[:iv])
    # raw_tag = decode(params[:tag])
    raw_ciphertext = decode(params[:ciphertext])
    puts "\nPre-slice ciphertext: #{params[:ciphertext]}"
    raw_tag = raw_ciphertext.slice!(-16, decode(params[:key]).length)
    tag = encode(raw_tag)
    ciphertext = encode(raw_ciphertext)
    puts "\nPost-slice tag: #{tag}"
    puts "\nPost-slice ciphertext: #{ciphertext}"

    @result = {
      iv: params[:iv],
      tag: encode(raw_tag),
      ciphertext: encode(raw_ciphertext),
    }.to_json
  end

  def pack_it(arr)
    encode(arr.split(',').map {|i| i.to_i}.pack('c*'))
  end
end