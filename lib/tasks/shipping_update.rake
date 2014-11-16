namespace :shipping_update do
  def send_error_email exception
    Spree::NotifyMailer.notify_email("failed to update shipping status:[#{exception.message}]", exception.backtrace).deliver
  end
  def send_notify_email subject, body
    Spree::NotifyMailer.notify_email(subject, body).deliver
  end
  def ship_log str
     Rails.logger.info "shipping-update:#{str}"
  end
  desc "shipping status update from amazon web-page"
  task amazon_scraping: :environment do
    begin
      ship_log "start amazon_shipping_scraping"
      scraper = Spree::AmazonScraper.new
      raise "Login failed!" unless scraper.login(scraper.login_info['userid'], scraper.login_info['password'])
      Spree::Shipment.where(state: ['pending', 'ready']).where.not(:state => 'canceled').where.not(json_store_order_id: nil).find_each do |shipment|
        ship_log "shipment.id:#{shipment.id}"
        ship_log "shipment store_order_id#{shipment.json_store_order_id}"
        if (1.second.ago - shipment.created_at) > 5.days
          send_notify_email "check shipment status" "orderid:#{shipment.order.number} / created_at:#{shipment.created_at}"
          next
        end
        store_order_id = shipment.json_store_order_id
        store_order_id.each do |store, order_ids|
          next if store != 'amazon'
          order_ids.each do |order_id|
            ship_log "store:#{store}, order_id:#{order_id}"
            addr = "#{scraper.addresses['order_status']}#{order_id}"
            ship_log "addr:#{addr}"
            order_status_page = scraper.get_html_doc addr
            raise "order status page not found! store_order_id:#{shipment.id}" if order_status_page == nil
            us_tracking_ids = []
            shipment_divs = scraper.get_multiple_text(order_status_page, scraper.selectors['shipping_div'])
            shipment_divs.each do |page|
              order_status = page.at_css(scraper.selectors['shipping_status']).text.strip
              raise "couldn't get order status in amazon! store_order_id:#{id}" if order_status.nil?
              ship_log "order_status:[#{order_status}]"
              next unless order_status == 'Shipped' or order_status == 'Delivered' or order_status == 'In transit'
              us_tracking_id = scraper.get_tracking_id page
              raise "couldn't get tracking id from amazon order id#{order_id}" if us_tracking_id.nil?
              ship_log "us_tracking_id[#{us_tracking_id}]"
              us_tracking_ids.push us_tracking_id
            end
            shipment.push_us_tracking_id store, order_id, us_tracking_ids if shipment_divs.count == us_tracking_ids.count
          end
        end
        if shipment.all_shipped?
          shipment.complete_ship
          shipment.save
        end
      end
    rescue Exception => e
      ship_log "error occured: #{$!}"
      ship_log e.backtrace
      send_error_email e
    end
  end

  desc "shipping status update from gap web-page"
  task gap_scraping: :environment do
    begin
      ship_log "start gap_shipping_scraping"
      scraper = Spree::GapScraper.new
      Spree::Shipment.where(state: ['pending', 'ready']).where.not(:state => 'canceled').where.not(json_store_order_id: nil).find_each do |shipment|
        ship_log "shipment.id:#{shipment.id}"
        ship_log "shipment store_order_id#{shipment.json_store_order_id}"
        if (1.second.ago - shipment.created_at) > 5.days
          send_notify_email "check shipment status" "orderid:#{shipment.order.number} / created_at:#{shipment.created_at}"
          next
        end
        store_order_id = shipment.json_store_order_id
        store_order_id.each do |store, order_ids|
          next if store != 'gap' and store != 'bananarepublic'
          order_ids.each do |order_id|
            ship_log "store:#{store}, order_id:#{order_id}"
            order_status_page = scraper.get_order_page order_id
            raise "order status page not found! store_order_id:#{shipment.id}" if order_status_page == nil
            next if "Shipped" != scraper.get_single_text(order_status_page, scraper.selectors['order_status']).text
            us_tracking_ids = []
            shipment_status_page = scraper.get_shipment_page order_id
            shipment_divs = scraper.get_multiple_text(shipment_status_page, scraper.selectors['shipping_div'])
            shipment_divs.each do |page|
              binding.pry
              us_tracking_id = scraper.get_single_text(page, scraper.selectors['us_tracking_id']).text
              raise "couldn't get tracking id from amazon order id#{order_id}" if us_tracking_id.nil?
              ship_log "us_tracking_id[#{us_tracking_id}]"
              us_tracking_ids.push us_tracking_id
            end
            shipment.push_us_tracking_id store, order_id, us_tracking_ids
          end
        end
        if shipment.all_shipped?
          shipment.complete_ship
          shipment.save
        end
      end
    rescue Exception => e
      ship_log "error occured: #{$!}"
      ship_log e.backtrace
      send_error_email e
    end
  end

  desc "getting information from the82"
  task the82_api_update: :environment do
    begin
      api = Spree::The82Api.new
      Spree::Shipment.where(after_shipped_state: ['local_delivery', 'local_delivery_complete']).where.not(:state => 'canceled').find_each do |shipment|
        if shipment.forwarding_id.nil?
          send_notify_email "forwarding_id is nil" "orderid:#{shipment.order.number} / created_at:#{shipment.created_at}"
          next
        end
        if (1.second.ago - shipment.created_at) > 10.days
          send_notify_email "check shipment status" "orderid:#{shipment.order.number} / created_at:#{shipment.created_at}"
          next
        end
        page = api.post_shipment_status shipment

        if status == "IC" #입고완료
          shipment.complete_local_delivery
        elsif status == "EI"  #오류입고
          send_notify_email "check shipment status:오류입고" "orderid:#{shipment.order.number} / created_at:#{shipment.created_at}"
        elsif status == "OC"  #출고완료
          shipment.start_oversea_delivery
        elsif status == "RC"  #수취완료
          shipment.complete_domestic_delivery
        end
      end
    rescue Exception => e
      ship_log "error occured: #{$!}"
      ship_log e.backtrace
      send_error_email e
    end
  end
  desc "tracking shipping inside of korea"
  task tracking_korean_shipping: :environment do
    begin
      scraper = Spree::The82Scraper.new
      Spree::Shipment.where(after_shipped_state: ['overseas_delivery', 'customs', 'domestic_delivery']).where.not(:state => 'canceled').find_each do |shipment|
        if shipment.json_kr_tracking_id.nil?
          send_notify_email "json_kr_tracking_id is nil" "orderid:#{shipment.order.number} / created_at:#{shipment.created_at}"
          next
        end
        if (1.second.ago - shipment.created_at) > 15.days
          send_notify_email "check shipment status" "orderid:#{shipment.order.number} / created_at:#{shipment.created_at}"
          next
        end
        page = scraper.get_shipment_status shipment.json_kr_tracking_id
        puts page.to_html
        unless scraper.get_single_text(page, scraper.selectors['custom_info']).text.include? "등록된 자료가 없습니다"
          if scraper.get_single_text(page, scraper.selectors['postoffice_info']).text.include? "배달완료"
            shipment.complete_domestic_delivery
          else
            shipment.start_domestic_delivery
          end
        end
      end
    rescue Exception => e
      ship_log "error occured: #{$!}"
      ship_log e.backtrace
      send_error_email e
    end
  end
end
