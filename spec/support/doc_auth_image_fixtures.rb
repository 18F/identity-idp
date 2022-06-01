module DocAuthImageFixtures
  def self.document_front_image
    load_image_data('id-front.jpg')
  end

  def self.document_front_image_multipart
    Rack::Test::UploadedFile.new(fixture_path('id-front.jpg'), 'image/jpeg')
  end

  def self.document_front_image_data_uri
    "data:image/jpeg;base64,#{Base64.strict_encode64(document_front_image)}"
  end

  def self.document_back_image
    load_image_data('id-back.jpg')
  end

  def self.document_back_image_multipart
    Rack::Test::UploadedFile.new(fixture_path('id-back.jpg'), 'image/jpeg')
  end

  def self.document_face_image
    load_image_data('id-face.jpg')
  end

  def self.document_face_image_multipart
    Rack::Test::UploadedFile.new(fixture_path('id-face.jpg'), 'image/jpeg')
  end

  def self.selfie_image
    load_image_data('selfie.jpg')
  end

  def self.selfie_image_multipart
    Rack::Test::UploadedFile.new(fixture_path('selfie.jpg'), 'image/jpeg')
  end

  def self.error_yaml_multipart
    path = File.join(
      File.dirname(__FILE__),
      '../fixtures/ial2_test_credential_forces_error.yml',
    )
    Rack::Test::UploadedFile.new(path, Mime[:yaml])
  end

  def self.error_yaml_no_db_multipart
    path = File.join(
      File.dirname(__FILE__),
      '../fixtures/ial2_test_credential_no_dob.yml',
    )
    Rack::Test::UploadedFile.new(path, Mime[:yaml])
  end

  def self.fixture_path(filename)
    File.join(
      File.dirname(__FILE__),
      '../fixtures/doc_auth_images',
      filename,
    )
  end

  def self.load_image_data(filename)
    File.read(fixture_path(filename))
  end
end
