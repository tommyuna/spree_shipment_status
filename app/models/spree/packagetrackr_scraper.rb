require 'open-uri'
require 'mechanize'

module Spree
  class PackagetrackrScraper < Spree::ScraperBase
    def initialize
      super
      @agent = Mechanize.new
      @agent.user_agent = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_9_4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/36.0.1985.143 Safari/537.36'
      @addresses = get_config 'webpage.packagetrackr.address'
      @selectors = get_config 'webpage.packagetrackr.selector'
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
    def get_status tracking_id
      address = "#{@addresses[:track]}#{tracking_id}"
      page = self.get_html_doc address
      if page.present?
        status = self.get_single_text page, @selectors[:status]
      end
      status
    end
  end
end
