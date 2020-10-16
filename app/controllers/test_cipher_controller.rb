class TestCipherController < ApplicationController
  skip_before_action :verify_authenticity_token

  def show
    puts 'TestCipherController#show'
  end
  
  def update
    puts 'TestCipherController#update'
    payload = params.slice(:iv, :tag, :ciphertext)
    key = params[:key]
    @plaintext = Encryption::AesCipher.new.decrypt(payload, key)
    render :show
  end
end