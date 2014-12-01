require 'open-uri'
require 'mechanize'
module Spree
  class The82Api < Spree::ScraperBase
    attr_reader :xpaths

    def initialize
      super
      @agent = Mechanize.new
      @addresses = get_config 'api.the82.address'
      @selectors = get_config 'api.the82.selector'
      @xpaths = get_config 'api.the82.xpath'
    end

    def post_shipment_status shipment
      parameters = {}
      parameters[:userid] = ENV['OHMYZIP_USERID']
      parameters[:authkey] = ENV['OHMYZIP_PASSWORD']
      if shipment.json_kr_tracking_id
        parameters[:transnum] = shipment.json_kr_tracking_id
      else
        parameters[:orderno] = shipment.order.number
      end
      page = @agent.post self.addresses['shipment_status'], parameters
      Nokogiri::XML(page.body)
    end

    def post_shipment_registration shipment
      parameters = self.assign_data_for_registration shipment
      Rails.logger.info "shipping-update" + parameters.to_s
      page = @agent.post self.addresses['shipment_registration'], parameters
      rtn = {}
      page.body.split("|").each do |str|
        tmp = str.split("=")
        rtn[tmp[0]] = tmp[1]
      end
      rtn
    end
    def assign_data_for_registration shipment
      address = shipment.address
      order = shipment.order
      rtn = {}
      rtn.compare_by_identity
      rtn["gubun"] = 'D'
      rtn["jisa"] = 'IL'
      rtn["custid"] = ENV['OHMYZIP_USERID']
      rtn["authkey"] = ENV['OHMYZIP_PASSWORD']
      rtn["receiverkrnm"] = replace_comma(address.firstname)
      rtn["receiverennm"] = replace_comma("")
      rtn["mobile"] = replace_comma(address.phone).delete(' ')
      rtn["tax"] = "com"
      rtn["zipcode"] = replace_comma(address.zipcode).delete(' ')
      rtn["address1"] = replace_comma(address.address1)
      rtn["address2"] = replace_comma(address.address2)
      rtn["listpass"] = "1"
      rtn["detailtype"] = "1"
      rtn["package"] = "1"
      rtn["package2"] = "1"
      rtn["isinvoice"] = "1"
      rtn["protectpackage"] = "0"
      order.line_items.each do |li|
        var = li.variant
        prod = li.product
        rtn["ominc"] = order.number
        rtn["brand"] = replace_comma(prod.brand)
        rtn["prodnm"] = replace_comma(prod.name)
        rtn["produrl"] = "https://gosnapshop.com/products/#{prod.slug}"
        rtn["prodimage"] = "https://gosnapshop.com#{prod.images.first.attachment.url("large")}"
        properties = prod.product_properties.select {|pp| pp.property.name == 'Color'}
        unless properties.empty?
          rtn["prodcolor"] = replace_comma(properties.first.value)
        end
        unless var.size.nil?
          rtn["prodsize"] = replace_comma(var.size)
        end
        rtn["qty"] = li.quantity.to_s
        rtn["cost"] = li.price.to_f.to_s
        unless shipment.json_store_order_id[prod.merchant].empty?
          rtn["orderno"] = shipment.json_store_order_id[prod.merchant].join(",")
          rtn["trackno"] = shipment.json_us_tracking_id[prod.merchant].map{|k,v|v}.join(",")
        end
        rtn["spnm"] = "SNAPSHOP"
        rtn["deliveryType"] = "3"
        rtn["custordno"] = order.number
        rtn["category"] = convert_the82_taxon prod.get_valid_taxon
      end
      rtn
    end

    private
    def replace_comma string
      if string.nil? or string.empty?
        "N/A"
      else
        string.gsub(",", " ").gsub("'", " ").gsub("`", " ")
      end
    end
    def convert_the82_taxon taxon
      case taxon.id
      when 72, 82, 159, 160
        return "ACCESSORIES"
      when 52, 51, 64, 49, 50, 154, 48, 53, 152
        return "BABIES GARMENTS"
      when 79, 71, 80, 149, 146, 148, 76, 147
        return "BAGS"
      when 162, 163
        return "BELT OF LEATHER"
        #return "GLOVE OF LEATHER"
      when 158, 150
        return "HAT"
      when 40, 47
        return "KNITTED T-SHIRTS"
      when 38
        return "MENS COAT"
      when 39
        return "MENS JACKETS"
      when 36, 37, 60
        return "MENS PANTS"
        #return "MENS SUITS"
      when 34, 35
        return "MENS T-SHIRTS"
        #return "FABRIC GLOVES"
        #return "OTHER GARMENT"
        #return "SCARF"
      when 22,24,25,155,14,59,10,13,11,12,9,26,28,29,169,65,153,16,20,17,15,19,18
        return "SHOES"
      when 45, 55
        return "SKIRTS"
      when 77
        return "SOCKS"
      when 73
        return "SUNGLASSES"
      when 81
        return "TIE"
        #return "VEST"
      when 83, 84, 74, 78
        return "WATCH"
      when 58, 57, 151, 42
        return "WOMANS CLOTHING"
      when 61
        return "WOMANS COAT"
      when 46
        return "WOMANS JACKETS"
      when 43, 44, 56
        return "WOMANS PANTS"
      when 54, 62, 41
        return "WOMANS T-SHIRTS"
      end

    end
  end
end
