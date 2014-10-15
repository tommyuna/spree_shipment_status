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
        #cookie = Mechanize::Cookie.new :domain => '.amazon.com', :name => name, :value => value, :path => '/', :expires => (Date.today + 1).to_s
        #@agent.cookie_jar << cookie
        @agent.get 'https://www.amazon.com'
        puts @agent.cookie_jar.to_a
        page = @agent.post( 'https://www.amazon.com/ap/signin?_encoding=UTF8&openid.assoc_handle=usflex&openid.claimed_id=http%3A%2F%2Fspecs.openid.net%2Fauth%2F2.0%2Fidentifier_select&openid.identity=http%3A%2F%2Fspecs.openid.net%2Fauth%2F2.0%2Fidentifier_select&openid.mode=checkid_setup&openid.ns=http%3A%2F%2Fspecs.openid.net%2Fauth%2F2.0&openid.ns.pape=http%3A%2F%2Fspecs.openid.net%2Fextensions%2Fpape%2F1.0&openid.pape.max_auth_age=0&openid.return_to=https%3A%2F%2Fwww.amazon.com%2Fgp%2Fyourstore%2Fhome%3Fie%3DUTF8%26ref_%3Dnav_custrec_signin',
                            { "email"       => id,
                              "create"      => 0,
                              "password"    => password,
                              "login_url"   => "../account/"
                            }
                          )
      rescue Net::ReadTimeout
        if @retry_cnt < 5 then
          @retry_cnt += 1
          Rails.logger.info "retry #{@retry_cnt}times"
          sleep(3)
          retry
        end
      end
      #puts "#{page.body}"
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
