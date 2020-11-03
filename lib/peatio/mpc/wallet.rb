module MPC
  class Wallet < Peatio::Wallet::Abstract
    def initialize(custom_features = {})
      @features = custom_features.slice(*SUPPORTED_FEATURES)
      @settings = {}
    end

    def configure(settings = {})
      # Clean client state during configure.
      @client = nil

      @settings.merge!(settings.slice(*SUPPORTED_SETTINGS))

      wallet = @settings.fetch(:wallet) do
        raise Peatio::Wallet::MissingSettingError, :wallet
      end.slice(:uri, :address, :secret, :access_token, :wallet_id, :testnet)

      currency = @settings.fetch(:currency) do
       raise Peatio::Wallet::MissingSettingError, :currency
      end.slice(:id, :base_factor, :code, :options)

      # Configure go microservice with required params
      client.configure(wallet, currency, @features, @settings.except(:wallet, :currency))
    end

    def create_address!(options = {})
      # Delegate to go microservice
      client.generate_address
    rescue MPC::Client::Error => e
      raise Peatio::Wallet::ClientError, e
    end

    def create_transaction!(transaction, options = {})
      # Delegate to go microservice
      # 1) Forge tx
      # 2) Broadcast
      transaction = client.create_transaction(transaction, options)
      # transaction parameters which should be in response
      #       hash: '0x5d0ef9697a2f3ea561c9fbefb48e380a4cf3d26ad2be253177c472fdd0e8b486',
      #       txout: 1,
      #       to_address: '0x9af4f143cd5ecfba0fcdd863c5ef52d5ccb4f3e5',
      #       amount: 0.01,
      #       block_number: 7732274,
      #       currency_id: 'eth',
      #       status: 'success'
    rescue MPC::Client::Error => e
      raise Peatio::Wallet::ClientError, e
    end

    def prepare_deposit_collection!(transaction, deposit_spread, deposit_currency)
      # TODO
    end

    def load_balance!
      # Delegate to go microservice
      client.load_balance
    rescue MPC::Client::Error => e
      raise Peatio::Wallet::ClientError, e
    end

    private

    def client
      @client ||= Client.new(ENV['GO_MICROSERVICE_URI'], idle_timeout: 1)
    end
  end
end
