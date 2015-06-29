require "active_support/core_ext/hash"
require 'active_support/builder'
require "net/http"
require "uri"
require "rexml/document"

module LemonWay
  class Client

    @@api_method_calls = %w(
      FastPay
      GetBalances
      GetKycStatus
      GetMoneyInIBANDetails
      GetMoneyInTransDetails
      GetMoneyOutTransDetails
      GetPaymentDetails
      GetWalletDetails
      MoneyIn
      MoneyIn3DConfirm
      MoneyIn3DInit
      MoneyInWebInit
      MoneyInWithCardId
      MoneyOut
      RefundMoneyIn
      RegisterCard
      RegisterIBAN
      RegisterWallet
      SendPayment
      UnregisterCard
      UpdateWalletDetails
      UpdateWalletStatus
      UploadFile
    )

    attr_reader :uri, :xml_mini_backend, :entity_expansion_text_limit, :options, :proxy

    def initialize opts = {}
      @options = opts.symbolize_keys!.except(:uri, :xml_mini_backend, :proxy).camelize_keys
      @uri = URI.parse opts[:uri]
      @xml_mini_backend = opts[:xml_mini_backend] || ActiveSupport::XmlMini_REXML
      @proxy = URI.parse opts[:proxy] unless opts[:proxy].nil?
      @entity_expansion_text_limit = opts[:entity_expansion_text_limit] || 10**20
    end

    def method_missing *args, &block
      camelized_method_name = args.first.to_s.camelize
      if @@api_method_calls.include? camelized_method_name
        attrs = attrs_from_options args.extract_options!
        query camelized_method_name, attrs, &block
      else
        super
      end
    end

    private

    def make_body(method_name, attrs={})
      options = {}
      options[:builder] = Builder::XmlMarkup.new(:indent => 2)
      options[:builder].instruct!
      options[:builder].tag! "soap12:Envelope",
                             "xmlns:SOAP-ENV" => "http://schemas.xmlsoap.org/soap/envelope/",
                             "xmlns:ns1"=>"https://ws.hipay.com/soap/payment-v2" do
        options[:builder].tag! "SOAP-ENV:Body" do
          options[:builder].__send__(:method_missing, method_name.to_s.camelize, xmlns: "Service_mb") do
            @options.merge(attrs).each do |key, value|
              ActiveSupport::XmlMini.to_tag(key, value, options)
            end
          end
        end
      end
    end

    def query(method, attrs={})
      http = @proxy.nil? ? Net::HTTP.new(@uri.host, @uri.port) : Net::HTTP.new(@uri.host, @uri.port, @proxy.host, @proxy.port, @proxy.user, @proxy.password)
      http.use_ssl  = true if @uri.port == 443

      req           = Net::HTTP::Post.new(@uri.request_uri)
      req.body      = make_body(method, attrs)
      req.add_field 'Content-type', 'text/xml; charset=utf-8'

      response = http.request(req).read_body

      with_custom_parser_options do
        response = Hash.from_xml(response)["Envelope"]['Body']["#{method}Response"]["#{method}Result"]
        response = Hash.from_xml(response).with_indifferent_access.underscore_keys(true)
      end

      if response.has_key?("e")
        raise Error, [response["e"]["code"], response["e"]["msg"]].join(' : ')
      elsif block_given?
        yield(response)
      else
        response
      end
    end

    # quickly retreat date and big decimal potential attributes
    def attrs_from_options attrs
      attrs.symbolize_keys!.camelize_keys!
      [:amount, :amountTot, :amountCom].each do |key|
        attrs[key] = sprintf("%.2f",attrs[key]) if attrs.key?(key) and attrs[key].is_a?(Numeric)
      end
      [:updateDate].each do |key|
        attrs[key] = attrs[key].to_datetime.utc.to_i.to_s if attrs.key?(key) and [Date, Time].any?{|k| attrs[key].is_a?(k)}
      end
      attrs
    end

    # work around for
    # - Nokogiri::XML::SyntaxError: xmlns: URI Service_mb is not absolute
    # - RuntimeError: entity expansion has grown too large
    def with_custom_parser_options &block
      backend = ActiveSupport::XmlMini.backend
      ActiveSupport::XmlMini.backend= @xml_mini_backend
      text_limit = REXML::Document.entity_expansion_text_limit
      REXML::Document.entity_expansion_text_limit = @entity_expansion_text_limit
      yield
    ensure
      ActiveSupport::XmlMini.backend = backend
      REXML::Document.entity_expansion_text_limit = text_limit
    end

    class Error < Exception; end
  end

end

