require 'open-uri'
require 'mechanize'
require 'cgi'
require 'rest_client'
module Spree
  class TheclassApi < Spree::ScraperBase
    def initialize
      super
      @url = "http://www.theclassusa.com/openapi"
      @uid = 'snapshop'
      @confmKey = 'fZ9bPqkmAgw47vFruRlsa5VUy'
    end
    def shipment_status shipment, forwarding_id = nil
      return unless shipment.forwarding_id and forwarding_id
      id = shipment.forwarding_id
      id = forwarding_id unless id.nil?
      res = RestClient.get @url, {:params => { "apikey" => "getdelivery", "uid" => @uid, "confmKey" => @confmKey, "order_no" => id }}
      rtn = JSON.parse(res.strip[1..-3])
      rtn
    end
    def shipment_registration shipment
      parameters = assign_data_for_registration shipment
      parameters.merge!({ "apikey" => "adddelivery", "uid" => @uid, "confmKey" => @confmKey })
      Rails.logger.info "shipping-update:#{parameters}"
      query = @url + "?" + parameters.to_query
      res = RestClient.get query
      rtn = JSON.parse(res.strip[1..-3])
      rtn
    end
    def assign_data_for_registration shipment
      address = shipment.address
      order = shipment.order
      options = {}
      options[:d_gubun] = 1
      options[:branch] = 1
      options[:cons_nkor] = convert_korean_name(address.firstname)
      options[:cons_certno] = address.customs_no if address.customs_no.present?
      options[:cons_tell] = address.phone
      options[:cons_hp] = address.phone
      options[:cons_addno] = address.zipcode
      options[:cons_addr] = address.address1
      options[:cons_addr2] = address.address2
      options[:post_memo] = address.other_comment if address.other_comment.present?
      options[:member_ordno] = order.number
      options['item_info'] = []
      i = 0
      order.line_items.each do |li|
        var = li.variant
        prod = li.product
        item_info_name = "item_info[#{i}]"
        options[item_info_name] = {}
        options[item_info_name][:item_shop] = prod.merchant
        options[item_info_name][:item_name] = prod.name
        options[item_info_name][:item_qty] = li.quantity
        options[item_info_name][:item_price] = li.price.to_f
        options[item_info_name][:item_gubn] = get_hs_code prod
        properties = prod.product_properties.select {|pp| pp.property.name == 'Color'}
        if properties.empty?
          options[item_info_name][:item_color] = "N/A"
        else
          options[item_info_name][:item_color] = properties.first.value
        end
        size = var.option_values.select { |o| o.option_type.name.include? "size" }
        if size.empty?
          options[item_info_name][:item_size] = "N/A"
        else
          options[item_info_name][:item_size] = size.name
        end
        options[item_info_name][:item_url] = "https://gosnapshop.com/products/#{prod.slug}"
        options[item_info_name][:item_img] = prod.try(:images).try(:first).try(:attachment).url("large")
        unless shipment.json_store_order_id[prod.merchant].nil? or shipment.json_store_order_id[prod.merchant].empty?
          orderno = shipment.json_store_order_id[prod.merchant].join(" ")
          trackno = shipment.json_us_tracking_id[prod.merchant].map{|k,v|v}.join(" ")
          options[item_info_name][:item_orderno] = orderno
          options[item_info_name][:item_trno] = trackno
        end
        options[item_info_name][:item_brand] = prod.brand
        i += 1
      end
      options
    end
    def get_hs_code product
      taxon_permalink = product.taxons.pluck(:permalink).join
      if taxon_permalink.include? "shoes"
        return 64
      elsif taxon_permalink.include? "watchs"
        return 91
      elsif taxon_permalink.include? "jewelry"
        return 71
      elsif taxon_permalink.include? "hat"
        return 65
      end
      62 #clothing
    end
  end
end
