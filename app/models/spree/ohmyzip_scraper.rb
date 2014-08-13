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
      body = @agent.get(address).body
      unless body == nil
        return Nokogiri::HTML(@agent.get(address).body)
      else
        return nil
      end
    end
  end
end