
namespace :shipping_update do
  def send_notify_email exception
    Spree::NotifyMailer.notify_email("failed to update shipping status:[#{exception.message}]", exception.backtrace).deliver
  end
  def ship_log str
     Rails.logger.info "shipping-update:#{str}"
  end
  desc "shipping status update from amazon web-page"
  task amazon_scraping: :environment do
    begin
      ship_log "start amz_shipping_scraping"
      scraper = Spree::AmazonScraper.new
      raise "Login failed!" unless scraper.login(scraper.login_info['userid'], scraper.login_info['password'])
      #Spree::Shipment.where(state: ['pending', 'ready']).where.not(json_store_order_id: nil).find_each do |shipment|
        shipment = Spree::Shipment.find(1310)
        ship_log "store_order_id:#{shipment.id}"
        ship_log "shipment store_order_id#{shipment.json_store_order_id}"
        next if store_order_id.json_store_order_id.nil?
        store_order_id = shipment.json_store_order_id
        us_tracking_id = shipment.json_us_tracking_id
        next if store_order_id
        store_order_id.each do |store, order_id|
          #order_status_page = scraper.get_html_doc "#{scraper.addresses['order_status']}#{shipment.id}"
          #raise "order status page not found! store_order_id:#{shipment.id}" if order_status_page == nil
          #order_status = scraper.get_single_text(order_status_page, scraper.selectors['order_status']).text.strip
          #raise "couldn't get order status in amazon! store_order_id:#{id}" if order_status.nil?
          #ship_log "#{order_status}"
        end
        #next unless order_status == 'Shipped' or order_status == 'Delivered' or order_status == 'In transit'
        #shipment.complete_ship
        #shipment.save
      #end
    rescue Exception => e
      ship_log "error occured: #{$!}"
      ship_log e.backtrace
      send_notify_email e
    end
  end
  desc "getting information from the82"
  task the82_api_update: :environment do
    begin
    rescue Exception => e
      ship_log "error occured: #{$!}"
      ship_log e.backtrace
      send_notify_email e
    end
  end
  desc "getting information from the82"
  task tracking_korean_shipping: :environment do
    begin

    rescue Exception => e
      ship_log "error occured: #{$!}"
      ship_log e.backtrace
      send_notify_email e
    end
  end
end
