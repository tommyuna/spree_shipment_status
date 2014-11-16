require 'open-uri'
require 'mechanize'

module Spree
  class The82Scraper < Spree::OhmyzipScraper
    attr_reader   :status
    def initialize
      super
      @addresses = get_config 'webpage.the82.address'
      @selectors = get_config 'webpage.the82.selector'
    end
    def get_shipment_status kr_tracking_id
      page = @agent.get self.addresses['shipping_status']
      page = page.form_with(:name => 'StaInfoOfferAction') do |form|
        form.h_bl_no = kr_tracking_id
      end.submit
      Nokogiri::HTML(page.body, nil, 'EUC-KR')
    end
  end
end
