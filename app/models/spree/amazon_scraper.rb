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

    def login
      @retry_cnt = 0
      begin
        page = @agent.get 'https://www.amazon.com'
        page = @agent.click page.link_with(:text => /Sign in/)
        page = page.form_with(:name => 'signIn') do |form|
          form.email = @login_info['userid']
          form.password = @login_info['password']
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
        page = @agent.get(address)
        if Nokogiri::HTML(page.body).at_css(@selectors['login_form']).present?
          page = page.form_with(:name => 'signIn') do |form|
            form.email = @login_info['userid']
            form.password = @login_info['password']
          end.submit
        end
      rescue Net::ReadTimeout
        if @retry_cnt < 5 then
          @retry_cnt += 1
          Rails.logger.info "retry #{@retry_cnt}times"
          sleep(3)
          retry
        end
      end
      unless page == nil
        return Nokogiri::HTML(page.body)
      else
        return nil
      end
    end
    def get_tracking_id page
      tracking_link = page.at_css(self.selectors['tracking_link'])
      return 'N/A' if tracking_link.nil?
      addr = (tracking_link.attribute 'href').value
      page = @agent.get addr
      tracking_id = Nokogiri::HTML(page.body).at_css self.selectors['us_tracking_id']
      return tracking_id.text if tracking_id.present?
      nil
    end
  end
end
