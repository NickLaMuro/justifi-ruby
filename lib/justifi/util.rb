# frozen_string_literal: true

require "json"
require "cgi"

module Justifi
  module Util
    def self.normalize_params(params)
      case params
      when Hash
        params.dup.to_json
      else
        raise TypeError, "normalize_params expects a hash"
      end
    end

    # Normalizes header keys so that they're all lower case and each
    # hyphen-delimited section starts with a single capitalized letter. For
    # example, `request-id` becomes `Request-Id`. This is useful for extracting
    # certain key values when the user could have set them with a variety of
    # diffent naming schemes.
    def self.normalize_headers(headers)
      headers.each_with_object({}) do |(k, v), new_headers|
        k = k.to_s.tr("_", "-") if k.is_a?(Symbol)
        k = k.split("-").reject(&:empty?).map(&:capitalize).join("-")

        new_headers[k] = v
      end
    end

    # Encodes a hash of parameters in a way that's suitable for use as query
    # parameters in a URI.
    def self.encode_parameters(params)
      Util.flatten_params(params)
        .map { |k, v| "#{url_encode(k)}=#{url_encode(v)}" }.join("&")
    end

    # Encodes a string in a way that makes it suitable for use in a set of
    # query parameters in a URI or in a set of form parameters in a request
    # body.
    def self.url_encode(key)
      CGI.escape(key.to_s).
        # Don't use strict form encoding by changing the square bracket control
        # characters back to their literals. This is fine by the server, and
        # makes these parameter strings easier to read.
        gsub("%5B", "[").gsub("%5D", "]")
    end

    def self.flatten_params(params, parent_key = nil)
      result = []

      # do not sort the final output because arrays (and arrays of hashes
      # especially) can be order sensitive, but do sort incoming parameters
      params.each do |key, value|
        calculated_key = parent_key ? "#{parent_key}[#{key}]" : key.to_s
        if value.is_a?(Hash)
          result += flatten_params(value, calculated_key)
        elsif value.is_a?(Array)
          result += flatten_params_array(value, calculated_key)
        else
          result << [calculated_key, value]
        end
      end

      result
    end

    def self.flatten_params_array(value, calculated_key)
      result = []
      value.each_with_index do |elem, i|
        if elem.is_a?(Hash)
          result += flatten_params(elem, "#{calculated_key}[#{i}]")
        elsif elem.is_a?(Array)
          result += flatten_params_array(elem, calculated_key)
        else
          result << ["#{calculated_key}[#{i}]", elem]
        end
      end
      result
    end

    # Creates a computed signature that can verify the payload sent.
    # The Justifi.client_secret is used to encrypt the payload
    def self.compute_signature(params)
      payload = params.keys.sort.map { |k| "#{k}#{params[k]}" }.join("")
      OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha256"), Justifi.client_secret, payload)
    end
  end
end
