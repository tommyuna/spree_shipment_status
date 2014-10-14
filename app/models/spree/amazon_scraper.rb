require 'open-uri'
require 'mechanize'

module Spree
  class AmazonScraper < Spree::ScraperBase
    def initialize
      super
      @agent = Mechanize.new
      @agent.user_agent = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_9_4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/36.0.1985.143 Safari/537.36'
      @login_info['userid'] = ENV['AMAZON_USERID']
      @login_info['password'] = ENV['AMAZON_PASSWORD']
      @addresses = get_config 'webpage.amazon.address'
      @selectors = get_config 'webpage.amazon.selector'
    end

    def login id, password
      @retry_cnt = 0
      begin
      page = @agent.post('http://www.ohmyzip.com/account/mem_process.php',
                         { "shop_action" => "member_login",
                           "ajax_login"  => "on",
                           "member_id"   => id,
                           "member_pw"   => password,
                           "login_url"   => "../account/"})
      rescue Net::ReadTimeout
        if @retry_cnt < 5 then
          @retry_cnt += 1
          Rails.logger.info "retry #{@retry_cnt}times"
          sleep(3)
          retry
        end
      end
      Rails.logger.info "#{page.body}"
      if page.body == 'idpwErr' or page.body == 'idErr'
        return false
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
  end
end
