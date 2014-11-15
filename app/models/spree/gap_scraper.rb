require 'open-uri'
require 'mechanize'

module Spree
  class GapScraper < Spree::ScraperBase
    def initialize
      super
      @agent = Mechanize.new
      @agent.user_agent = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_9_4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/36.0.1985.143 Safari/537.36'
      @addresses = get_config 'webpage.gap.address'
      @selectors = get_config 'webpage.gap.selector'
    end

    def get_order_page order_id
      page = @agent.get self.addresses['order_status']
      page = page.form_with(:name => 'OrderLookupForm') do |form|
        form.orderNumber = order_id
        form.newEmailAddress = "hello@luuv.it"
      end.submit
      Nokogiri::HTML(page.body)
    end

    def get_html_doc address
      @retry_cnt = 0
      begin
        @body = @agent.get(address).body
      rescue Net::ReadTimeout
        if @retry_cnt < 5 then
          @retry_cnt += 1
          Rails.logger.info "retry #{@retry_cnt}times"
          sleep(3)
          retry
        end
      end
      unless @body == nil
        return Nokogiri::HTML(@body)
      else
        return nil
      end
    end
    def get_tracking_id page
      binding.pry
      addr = (page.at_css(self.selectors['tracking_link']).attribute 'href').value
      page = @agent.get addr
      (Nokogiri::HTML(page.body).at_css scraper.selectors['us_tracking_id']).text
    end
  end
end
