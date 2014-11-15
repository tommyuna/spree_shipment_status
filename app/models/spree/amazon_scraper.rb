require 'open-uri'
require 'mechanize'

module Spree
  class AmazonScraper < Spree::ScraperBase
    def initialize
      super
      @agent = Mechanize.new
      @agent.user_agent = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_9_4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/36.0.1985.143 Safari/537.36'
      @login_info['userid'] = ENV['AMAZON_EMAIL']
      @login_info['password'] = ENV['AMAZON_PASSWORD']
      @addresses = get_config 'webpage.amazon.address'
      @selectors = get_config 'webpage.amazon.selector'
    end

    def login id, password
      @retry_cnt = 0
      begin
        page = @agent.get 'https://www.amazon.com'
        page = @agent.click page.link_with(:text => /Sign in/)
        page = page.form_with(:name => 'signIn') do |form|
          form.email = id
          form.password = password
        end.submit
      rescue Net::ReadTimeout
        if @retry_cnt < 5 then
          @retry_cnt += 1
          Rails.logger.info "retry #{@retry_cnt}times"
          sleep(3)
          retry
        end
      end
      return true
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
      addr = (page.at_css(self.selectors['tracking_link']).attribute 'href').value
      page = @agent.get addr
      (Nokogiri::HTML(page.body).at_css self.selectors['us_tracking_id']).text
    end
  end
end