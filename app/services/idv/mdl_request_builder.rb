# frozen_string_literal: true

module Idv
  # Builds ISO 18013-7 DeviceRequest for the Digital Credentials API.
  class MdlRequestBuilder
    MDL_DOCTYPE = 'org.iso.18013.5.1.mDL'
    MDL_NAMESPACE = 'org.iso.18013.5.1'

    # Cipher suite 1 = P-256 + HKDF-SHA-256 + AES-256-GCM
    CIPHER_SUITE = 1

    REQUESTED_ELEMENTS = {
      'family_name' => false,
      'given_name' => false,
      'birth_date' => false,
      'issue_date' => false,
      'expiry_date' => false,
      'issuing_country' => false,
      'issuing_authority' => false,
      'document_number' => false,
      'portrait' => false,
      'driving_privileges' => false,
      'resident_address' => false,
      'resident_city' => false,
      'resident_state' => false,
      'resident_postal_code' => false,
      'resident_country' => false,
      'sex' => false,
      'height' => false,
      'weight' => false,
      'eye_colour' => false,
    }.freeze

    attr_reader :session_id, :nonce, :ephemeral_private_key, :ephemeral_public_key

    def initialize
      @session_id = SecureRandom.uuid
      @nonce = SecureRandom.random_bytes(16)
      generate_ephemeral_keys
    end

    def build_request
      {
        protocol: 'org-iso-mdoc',
        data: build_request_data,
      }
    end

    # Returns the raw data structure for the Digital Credentials API request
    # Try both formats - CBOR (ISO 18013-7) and JSON (simplified)
    def build_request_data
      {
        # CBOR-encoded DeviceRequest per ISO 18013-5
        deviceRequest: encode_device_request,
        # CBOR-encoded encryption info
        encryptionInfo: encode_encryption_info,
        # Also provide JSON format in case Safari expects this
        docType: MDL_DOCTYPE,
        nameSpaces: {
          MDL_NAMESPACE => REQUESTED_ELEMENTS.transform_values { |_| false },
        },
        # Nonce for replay protection
        nonce: Base64.strict_encode64(@nonce),
        # Session identifier for correlation
        sessionId: @session_id,
      }
    end

    # Session data to store for response validation
    def session_data
      {
        session_id: @session_id,
        nonce: Base64.strict_encode64(@nonce),
        ephemeral_private_key: serialize_private_key,
        created_at: Time.zone.now.iso8601,
      }
    end

    private

    def generate_ephemeral_keys
      # Generate P-256 (secp256r1) ephemeral key pair for session encryption
      @ephemeral_private_key = OpenSSL::PKey::EC.generate('prime256v1')
      @ephemeral_public_key = @ephemeral_private_key.public_key
    end

    def serialize_private_key
      Base64.strict_encode64(@ephemeral_private_key.to_der)
    end

    def encode_device_request
      # Build the DeviceRequest structure per ISO 18013-5 Section 8.3.2.1
      device_request = {
        'version' => '1.0',
        'docRequests' => [build_doc_request],
      }

      Base64.strict_encode64(CBOR.encode(device_request))
    end

    def build_doc_request
      # DocRequest structure per ISO 18013-5 Section 8.3.2.1.2
      {
        'itemsRequest' => build_items_request,
        # readerAuth would go here for signed requests (optional for web)
      }
    end

    def build_items_request
      # ItemsRequest structure - wrapped in CBOR tagged value (24) for bstr
      # Per ISO 18013-5, ItemsRequest is CBOR-encoded and tagged
      items_request_data = {
        'docType' => MDL_DOCTYPE,
        'nameSpaces' => build_name_spaces,
      }

      # Tag 24 indicates embedded CBOR (bstr .cbor ItemsRequest)
      CBOR::Tagged.new(24, CBOR.encode(items_request_data))
    end

    def build_name_spaces
      # Build the nameSpaces structure with requested data elements
      # Format: { namespace => { elementIdentifier => intentToRetain, ... } }
      {
        MDL_NAMESPACE => REQUESTED_ELEMENTS.transform_keys(&:to_s),
      }
    end

    def encode_encryption_info
      # Build encryption info for session establishment
      # This includes the reader's ephemeral public key in COSE_Key format
      encryption_info = {
        'cipherSuite' => CIPHER_SUITE,
        'readerEphemeralPublicKey' => encode_cose_key,
      }

      Base64.strict_encode64(CBOR.encode(encryption_info))
    end

    def encode_cose_key
      # Encode the ephemeral public key as a COSE_Key per RFC 8152
      # Key type 2 = EC2 (Elliptic Curve Keys w/ x- and y-coordinate pair)
      # Curve -7 = P-256

      # Get the raw public key point coordinates
      point = @ephemeral_public_key.to_bn
      # For P-256, the uncompressed point is 65 bytes: 0x04 || x (32 bytes) || y (32 bytes)
      point_bytes = point.to_s(2)

      # Skip the 0x04 prefix and extract x and y coordinates
      if point_bytes.length == 65 && point_bytes.getbyte(0) == 0x04
        x_coord = point_bytes[1, 32]
        y_coord = point_bytes[33, 32]
      else
        # Handle compressed or other formats
        x_coord = point_bytes[0, 32]
        y_coord = point_bytes[32, 32] || ("\x00" * 32)
      end

      {
        1 => 2,           # kty: EC2
        -1 => 1,          # crv: P-256
        -2 => x_coord,    # x coordinate
        -3 => y_coord,    # y coordinate
      }
    end
  end
end
