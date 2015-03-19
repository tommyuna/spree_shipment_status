require 'open-uri'
require 'mechanize'
module Spree
  class TheClassApi < Spree::ScraperBase
    attr_reader :xpaths

    def initialize
      super
      @agent = Mechanize.new
      @url = "http://www.theclassusa.com/openapi"
    end
    def post_shipment_status shipment
    end
    def post_shipment_registration shipment
    end
    def assign_data_for_registration shipment
      address = shipment.address
      order = shipment.order
      options = {}
      options[:apikey] = "adddelivery"
      options[:uid] = "snapshop"
      options[:confmKey] = "fZ9bPqkmAgw47vFruRlsa5VUy"
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
      options[:item_info] = []
      order.line_items.each do |li|
        var = li.variant
        prod = li.product
        item_info = {}
        item_info[:item_shop] = prod.merchant
        item_info[:item_name] = prod.name
        item_info[:item_qty] = li.quantity
        item_info[:item_price] = li.price
        item_info[:item_gubn] = get_hs_code prod
        properties = prod.product_properties.select {|pp| pp.property.name == 'Color'}
        item_info[:item_color] = properties.first.value unless properties.empty?
        size = var.option_values.find { |o| o.option_type.name.include? "size" }
        item_info[:item_size] = size.name unless size.nil?
        item_info[:item_url] = "https://gosnapshop.com/products/#{prod.slug}"
        item_info[:item_img] = prod.try(:images).try(:first).try(:attachment).url("large")
        unless shipment.json_store_order_id[prod.merchant].nil? or shipment.json_store_order_id[prod.merchant].empty?
          orderno = shipment.json_store_order_id[prod.merchant].join(" ")
          trackno = shipment.json_us_tracking_id[prod.merchant].map{|k,v|v}.join(" ")
          item_info[:item_orderno] = orderno
          item_info[:item_trno] = trackno
        end
        item_info[:item_brand] = prod.brand
        options[:item_info].push item_info
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
