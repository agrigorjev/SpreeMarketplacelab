require 'httparty'

module Marketplace
  class Api
    include Listenable

    def initialize(api_key, account_key, api_base_url)
      @api_key = api_key
      @account_key = account_key
      @api_base_url = api_base_url
    end

    def self.instance
      @instance ||= begin
        api_key = SpreeMarketplacelab::Config[:apiKey]
        account_key = SpreeMarketplacelab::Config[:accountKey]
        api_base_url = SpreeMarketplacelab::Config[:apiBaseUrl]

        self.new(api_key, account_key, api_base_url)
      end
    end

    def create_order(order_details)
      marketplace_order_details = convert_to_marketplace_order(order_details)
      post_api_response('/api/orders', '', marketplace_order_details)
    end

    def notify(event_name, data)
      notify_listeners(event_name, data)
    end

    # @listing_ids comma separated list of listings identifiers
    def get_deliveryoptions(listing_ids, country_code)
      get_api_response("/api/listings/#{listing_ids}/shippingmethods/#{country_code}")
    end

    # get listings for a product(s)
    # @product_ids comma separated list of product identifiers
    def get_listings(product_ids)
      get_api_response("/api/products/#{product_ids}/listings")
    end

    def get_listing(listing_id)
      listing = get_api_response("/api/listings/#{listing_id}")
      listing[0] if listing && listing.any?
    end

    def subscribe_to_webhooks
      subscribe_to :listing_created
    end

    private
      def convert_to_marketplace_order(spree_order)
        # todo: write a conversion here
        return spree_order
      end

      def logger
        @logger ||= MarketplaceLogger.new
      end

      def subscribe_to(subscription_type)
        int_subscription_type = case subscription_type
          when :listing_created then 6
          else 0
        end

        json = {
          HookSubscriptionType: int_subscription_type,
          TargetUrl: 'http://' + Spree::Config.site_url + '/marketplace/listener/listing'
        }.to_json

        post_api_response('/api/hooks', '', json)
      end

      def post_api_response(endpoint_url, params = '', json = '')
        url = "#{@api_base_url}#{endpoint_url}?#{params}&apikey=#{@api_key}&accountkey=#{@account_key}"
        logger.info "Marketplace POST #{url} #{json}"

        response = ::HTTParty.post(url, verify: false, body: json, headers: {'Content-Type' => 'application/json'})
        logger.info "Marketplace POST response code=#{response.code} content-length=#{response.headers['content-length']}"

        return (response.code >= 200 || response.code < 300)
      end

      def get_api_response(endpoint_url, params = '')
        url = "#{@api_base_url}#{endpoint_url}?#{params}&apikey=#{@api_key}&accountkey=#{@account_key}"
        logger.info "Marketplace GET #{url}"

        response = ::HTTParty.get(url, verify: false)
        logger.info "Marketplace GET response code=#{response.code} content-length=#{response.headers['content-length']}"

        return convert_array_to_ruby_style(response) if response && response.code == 200
      end

      def convert_array_to_ruby_style(camel_case_arr)
        ruby_arr = []

        camel_case_arr.each do |arr_item|
          ruby_case_hash = {}
          arr_item.each_pair do |key, val|
            # if value is a Hash we convert keys to ruby_style
            val = convert_hash_to_ruby_style val if val.is_a? Hash

            # if value is an Array we iterate over it and change items
            if val.is_a? Array
              val.map! do |item|
                item = convert_hash_to_ruby_style item if item.is_a? Hash
              end
            end

            # add converted hash pair to new has
            ruby_case_hash.merge!({get_underscored_key(key) => val})
          end
          ruby_arr.push(ruby_case_hash)
        end
        ruby_arr
      end

      def convert_hash_to_ruby_style(camel_case_hash)
        ruby_case_hash = {}
        camel_case_hash.each_pair do |key, val|
          # if value is a Hash we convert keys to ruby_style
          val = convert_hash_to_ruby_style val if val.is_a? Hash

          # if value is an Array we iterate over it and change items
          if val.is_a? Array
            val.map! do |item|
              item = convert_hash_to_ruby_style item if item.is_a? Hash
            end
          end

          # add converted hash pair to new has
          ruby_case_hash.merge!({get_underscored_key(key) => val})
        end
        ruby_case_hash
      end

      def get_underscored_key(key)
        underscored_key = ActiveSupport::Inflector.underscore(key)
        underscored_key = underscored_key.downcase.tr(" ", "_")
      end
  end
end