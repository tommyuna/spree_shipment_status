module Spree
  class The82Api
    def initialize
      shipping_config = YAML.load_file("#{Rails.root}/config/shipping_update.yml")
      @config = shipping_config["#{ENV['RAILS_ENV'] || "development"}"]
    end
  end
end
