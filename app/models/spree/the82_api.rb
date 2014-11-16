require 'open-uri'
require 'mechanize'
module Spree
  class The82Api < Spree::ScraperBase
    def initialize
      super
      @agent = Mechanize.new
      @addresses = get_config 'api.the82.address'
      @selectors = get_config 'api.the82.selector'
    end

    def post_shipment_status shipment
      parameters = {}
      parameters[:userid] = ENV['OHMYZIP_USERID']
      parameters[:authkey] = ENV['OHMYZIP_PASSWORD']
      if shipment.forwarding_id
        parameters[:transnum] = shipment.forwarding_id
      else
        parameters[:orderno] = shipment.order.number
      end
      page = @agent.post self.addresses['shipment_status'], parameters
      Nokogiri::XML(page.body)
    end

    def post_shipment_registration shipment
      arguments = self.assign_data_for_registration shipment
      parameters = arguments.dup
      parameters.delete :products
      arguments[:products].each do |prod|
        parameters.merge prod
        Rails.logger.debug parameters
        page = @agent.post self.addresses['shipment_registration'], parameters
        Nokogiri::XML(page.body)
      end
      Nokogiri::XML(page.body)
    end
    def assign_data_for_registration shipment
      address = shipment.address
      order = shipment.order
      rtn = {}
      rtn[:gubun] = 'D'
      rtn[:jisa] = 'IL'
      rtn[:custid] = ENV['OHMYZIP_USERID']
      rtn[:authkey] = ENV['OHMYZIP_PASSWORD']
      rtn[:receiverkrnm] = replace_comma(address.firstname)
      rtn[:receiverennm] = " "
      rtn[:mobile] = replace_comma(address.phone)
      rtn[:tax] = replace_comma(address.phone)
      rtn[:zipcode] = replace_comma(address.zipcode)
      rtn[:address1] = replace_comma(address.address1)
      rtn[:address2] = replace_comma(address.address2)
      rtn[:listpass] = "1"
      products = []
      order.line_items.each do |li|
        item = {}
        var = li.variant
        prod = li.product
        item[:brand] = replace_comma(prod.brand)
        item[:prodnm] = replace_comma(prod.name)
        item[:produrl] = "https://gosnapshop.com/products/#{prod.slug}"
        item[:prodimage] = "https://gosnapshop.com#{prod.images.first.attachment.url("large")}"
        properties = prod.product_properties.select {|pp| pp.property.name == 'Color'}
        unless properties.empty?
          item[:prodcolor] = replace_comma(properties.first.value)
        end
        item[:prodsize] = replace_comma(var.size) unless var.size.nil?
        item[:qty] = li.quantity
        item[:cost] = li.price.to_f
        item[:orderno] = shipment.json_store_order_id[prod.merchant].first unless shipment.json_store_order_id[prod.merchant].nil? or shipment.json_store_order_id[prod.merchant].empty?
        item[:spnm] = prod.merchant
        item[:deliveryType] = "3"
        item[:custordno] = order.number
        item[:category] = prod.get_taxon_name
        products.push item
      end
      rtn[:products] = products
      rtn
    end

    private
    def replace_comma string
      string.gsub ",", " " unless string.nil?
    end
  end
end
