module IdpHelper
  def get_help_image_uri(question)
    "help/#{File.basename(question['helpImageUrl'])}"
  end
end
