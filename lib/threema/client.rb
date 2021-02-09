require 'openssl'
require 'net/http'
require 'net/https'
require 'cgi'
require 'json'
require 'net/http/post/multipart'
require 'threema/exceptions'

class Threema
  class Client
    API_URL     = 'https://msgapi.threema.ch'.freeze

    class << self
      def url(path = '')
        "#{API_URL}#{path}"
      end
    end

    def initialize(api_identity:, api_secret:, public_key_pinning: true)
      @api_identity       = api_identity
      @api_secret         = api_secret
      @public_key_pinning = public_key_pinning
    end

    def get(url, params = {})
      response = handle_error do
        uri = authed_uri(url, params)
        req = Net::HTTP::Get.new(uri)

        request_https(uri, req)
      end
      response.body
    end

    def post_form_urlencoded(url, payload)
      response = handle_error do
        uri = URI(url)
        req = Net::HTTP::Post.new(uri)
        req.set_form_data(payload.merge(
                            from:   @api_identity,
                            secret: @api_secret,
        ))

        request_https(uri, req)
      end
      response.body
    end

    def post_json(url, params: {}, payload: {})
      response = handle_error do
        uri      = authed_uri(url, params)
        req      = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
        req.body = payload.to_json

        request_https(uri, req)
      end
      JSON.parse(response.body)
    end

    def post_multipart(url, params: {}, payload: {})
      response = handle_error do
        uri = authed_uri(url, params)
        req = Net::HTTP::Post::Multipart.new uri, payload

        request_https(uri, req)
      end
      response.body
    end

    def handle_error(&_block)
      response = yield
      return response if response.is_a?(Net::HTTPOK)
      raise Unauthorized if response.is_a?(Net::HTTPUnauthorized)
      raise RemoteError if response.is_a?(Net::HTTPInternalServerError)
      raise RequestError.new(response.class.name, response)
    end

    def chargeable(&_block)
      yield
    rescue RequestError => e
      raise if e.message != 'Net::HTTPPaymentRequired'
      raise CreditError, 'no credits remain'
    end

    def not_found_ok(&_block)
      yield
    rescue RequestError => e
      return if e.message == 'Net::HTTPNotFound'
      raise
    end

    private

    def request_https(uri, req)
      http = Net::HTTP.new(uri.host, uri.port).tap do |config|
        config.use_ssl = true
        config.verify_mode = OpenSSL::SSL::VERIFY_PEER
      end

      # for those special moments...
      # http.set_debug_output($stdout)

      http.request(req)
    end

    def authed_uri(url, params = {})
      uri       = URI(url)
      uri.query = URI.encode_www_form(authed(params))
      uri
    end

    def authed(params = {})
      params.merge(
        from:   @api_identity,
        secret: @api_secret,
      )
    end
  end
end
