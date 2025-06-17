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

  def self.document_passport_image
    load_image_data('passport.jpg')
  end

  def self.document_passport_image_multipart
    Rack::Test::UploadedFile.new(fixture_path('passport.jpg'), 'image/jpeg')
  end

  def self.selfie_image
    load_image_data('selfie.jpg')
  end

  def self.selfie_image_multipart
    Rack::Test::UploadedFile.new(fixture_path('selfie.jpg'), 'image/jpeg')
  end

  def self.selfie_image_data_uri
    "data:image/jpeg;base64,#{Base64.strict_encode64(selfie_image)}"
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

  def self.portrait_match_success_yaml
    path = File.join(
      File.dirname(__FILE__),
      '../fixtures/ial2_test_portrait_match_success.yml',
    )
    Rack::Test::UploadedFile.new(path, Mime[:yaml])
  end

  def self.portrait_match_fail_yaml
    path = File.join(
      File.dirname(__FILE__),
      '../fixtures/ial2_test_portrait_match_failure.yml',
    )
    Rack::Test::UploadedFile.new(path, Mime[:yaml])
  end

  def self.passport_passed_yaml
    path = File.join(
      File.dirname(__FILE__),
      '../fixtures/passport_credential.yml',
    )
    Rack::Test::UploadedFile.new(path, Mime[:yaml])
  end

  def self.passport_failed_yaml
    path = File.join(
      File.dirname(__FILE__),
      '../fixtures/passport_bad_mrz_credential.yml',
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

  def self.zipped_files(reference_id:, selfie: false, passport: false)
    temp_dir = Dir.mktmpdir(reference_id)

    if passport
      # i don't think this is possible with socure?
      FileUtils.cp(fixture_path('passport.jpg'), temp_dir)
    else
      FileUtils.cp(fixture_path('id-back.jpg'), "#{temp_dir}/documentfrontDoc_Back_1_blob.jpg")
      FileUtils.cp(fixture_path('id-front.jpg'), "#{temp_dir}/documentfrontDoc_Front_1_blob.jpg")
    end

    if selfie
      FileUtils.cp(fixture_path('selfie.jpg'), "#{temp_dir}/Doc_Selfie_1_blob.jpg")
    end

    zip_filename = "#{temp_dir}/document.zip"

    Zip::File.open(zip_filename, Zip::File::CREATE) do |zipfile|
      Dir.glob(File.join(temp_dir, '*')).each do |file|
        next if File.directory?(file)
        zipfile.add(File.basename(file), file)
      end
    end
    zip_contents = File.read(zip_filename)
    zip_contents
  ensure
    FileUtils.remove_entry_secure(temp_dir)
  end
end
