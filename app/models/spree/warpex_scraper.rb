require 'open-uri'
require 'mechanize'

module Spree
  class WarpexScraper < Spree::OhmyzipScraper
    attr_reader   :status
    def initialize
      super
      @addresses = get_config 'webpage.warpex.address'
      @selectors = get_config 'webpage.warpex.selector'
      @status = get_config 'webpage.warpex.status'
    end
    def login
    end
  end
end
