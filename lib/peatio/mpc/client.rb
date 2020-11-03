module MPC
  class Client
    Error = Class.new(StandardError)

    class ConnectionError < Error; end

    class ResponseError < Error
      def initialize(code, msg)
        super "#{msg} (#{code})"
      end
    end

    def initialize(endpoint, idle_timeout: 5)
      @json_rpc_endpoint = URI.parse(endpoint)
      @json_rpc_call_id = 0
      @path = @json_rpc_endpoint.path.empty? ? "/" : @json_rpc_endpoint.path
      @idle_timeout = idle_timeout
    end

    def rest_api(verb, path, data = nil)
      args = [@endpoint.to_s + path]

      if data
        if %i[post put patch].include?(verb)
          args << data.compact.to_json
          args << { 'Content-Type' => 'application/json' }
        else
          args << data.compact
          args << {}
        end
      else
        args << nil
        args << {}
      end

      args.last['Accept']        = 'application/json'
      args.last['Authorization'] = 'Bearer ' + @access_token

      response = Faraday.send(verb, *args)
      response.assert_success!
      response = JSON.parse(response.body)
      response['error'].tap { |error| raise ResponseError.new(error) if error }
      response
    rescue Faraday::Error => e
      raise ConnectionError, e
    end

    private

    def rpc_call_id
      @json_rpc_call_id += 1
    end

    def connection
      @connection ||= Faraday.new(@json_rpc_endpoint) do |f|
        f.adapter :net_http_persistent, pool_size: 5, idle_timeout: @idle_timeout
      end.tap do |connection|
        unless @json_rpc_endpoint.user.blank?
          connection.basic_auth(@json_rpc_endpoint.user, @json_rpc_endpoint.password)
        end
      end
    end
  end
end
