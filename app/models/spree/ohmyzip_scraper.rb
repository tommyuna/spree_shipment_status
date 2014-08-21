require 'open-uri'
require 'mechanize'

module Spree
  class OhmyzipScraper < Spree::ScraperBase
    def initialize
      super
      @agent = Mechanize.new
      @login_info['userid'] = ENV['OHMYZIP_USERID']
      @login_info['password'] = ENV['OHMYZIP_PASSWORD']
      @addresses = get_config 'webpage.ohmyzip.address'
      @selectors = get_config 'webpage.ohmyzip.selector'
    end

    def login id, password
      page = @agent.post('http://www.ohmyzip.com/account/mem_process.php',
                         { "shop_action" => "member_login",
                           "ajax_login"  => "on",
                           "member_id"   => id,
                           "member_pw"   => password,
                           "login_url"   => "../account/"})
      if page.body == 'idpwErr'
        return false
      end
      return true
    end

    def get_html_doc address
      @agent.user_agent = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_9_4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/36.0.1985.143 Safari/537.36' if @agent.user_agent == nil
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
