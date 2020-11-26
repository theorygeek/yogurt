# typed: strict
# frozen_string_literal: true

require 'uri'
require 'net/http'
require 'json'

module GraphQLClient
  class Http
    extend T::Sig
    include QueryExecutor

    sig {params(uri: String, headers: T::Hash[String, String]).void}
    def initialize(uri, headers: {})
      parsed = URI.parse(uri)
      if parsed.is_a?(URI::HTTP) || parsed.is_a?(URI::HTTPS)
        @uri = T.let(parsed, T.any(URI::HTTP, URI::HTTPS))
      else
        raise ArgumentError, "Invalid URI: #{uri} (must be HTTP or HTTPS)"
      end

      @headers = T.let(headers, T::Hash[String, String])
    end

    # You can override this method in a subclass to set options on the HTTP request
    sig {overridable.params(options: T.untyped).returns(T::Hash[String, String])}
    def headers(options)
      @headers
    end

    # You can override this in a subclass to get strongly typed options on auto-generated code
    sig {override.returns(T::Types::Base)}
    def options_type_alias
      T.type_alias {T.untyped}
    end

    sig do
      override.params(
        query: String,
        operation_name: String,
        variables: T.nilable(T::Hash[String, T.untyped]),
        options: T.untyped,
      ).returns(T::Hash[String, T.untyped])
    end
    def execute(query, operation_name:, variables: nil, options: nil)
      request = Net::HTTP::Post.new(@uri.request_uri)
      request.basic_auth(@uri.user, @uri.password) if @uri.user || @uri.password

      request["Accept"] = "application/json"
      request["Content-Type"] = "application/json"

      headers(options).each do |name, value|
        request[name] = value
      end

      body = T.let({}, T::Hash[String, T.untyped])
      body["query"] = query
      body["variables"] = variables if variables&.any?
      body["operationName"] = operation_name
      request.body = JSON.generate(body)

      response = connection.request(request)
      case response
      when Net::HTTPOK, Net::HTTPBadRequest
        JSON.parse(response.body)
      else
        { "errors" => [{ "message" => "#{response.code} #{response.message}" }] }
      end
    end

    # Returns an HTTP connection. You can override in subclasses to customize the conection.
    sig {overridable.returns(Net::HTTP)}
    def connection
      client = Net::HTTP.new(@uri.host, @uri.port)
      client.use_ssl = @uri.scheme == "https"

      client
    end
  end
end
