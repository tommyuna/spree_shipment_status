namespace :shipping_update do
  def send_error_email exception
    Spree::NotifyMailer.notify_email("failed to update shipping status:[#{exception.message}]", exception.backtrace).deliver
  end
  def ship_log str
    Rails.logger.info "shipping-update:#{str}"
  end
  def send_notify_email subject, body
    #Spree::NotifyMailer.notify_email(subject, body).deliver
  end
  desc "shipping status update from amazon web-page"
  task amazon_scraping: :environment do
    begin
      ship_log "start amazon_scraping"
      scraper = Spree::AmazonScraper.new
      raise "Login failed!" unless scraper.login
      Spree::Shipment.
        includes(:order)
        where(state: ['pending', 'ready']).
        where.not(:state => 'canceled').
        where.not(json_store_order_id: nil).
        where('created_at >= ?', DateTime.new(2014,12,6)).
        find_each do |shipment|
        next if shipment.order.state == 'canceled'
        ship_log "shipment.id:#{shipment.id}"
        ship_log "shipment store_order_id#{shipment.json_store_order_id}"
        if (1.second.ago - shipment.created_at) > 5.days
          send_notify_email "check shipment status","orderid: #{shipment.order.number} / created_at:#{shipment.created_at}"
        end
        unless shipment.after_shipped_state == 'before_ship'
          shipment.check_ship
        end
        store_order_id = shipment.json_store_order_id
        store_order_id.each do |store, order_ids|
          next if store != 'amazon'
          order_ids.each do |order_id|
            ship_log "store:#{store}, order_id:#{order_id}"
            next if order_id == "FAILED"
            addr = "#{scraper.addresses['order_status']}#{order_id}"
            ship_log "addr:#{addr}"
            order_status_page = scraper.get_html_doc addr
            raise "order status page not found! store_order_id:#{shipment.id}" if order_status_page == nil
            us_tracking_ids = []
            shipment_divs = scraper.get_multiple_text(order_status_page, scraper.selectors['shipping_div'])
            ship_log "shipment_divs:#{shipment_divs.count}"
            raise "shipment_divs doesn't exist:#{shipment.id}" if shipment_divs.count == 0
            shipment_divs.each do |page|
              order_status = page.at_css(scraper.selectors['shipping_status'])
              order_status = page.at_css(scraper.selectors['shipping_status_2']) if order_status.nil?
              raise "couldn't get order status in amazon! store_order_id:#{order_id}" if order_status.nil?
              ship_log "order_status:[#{order_status.text.strip}]"
              state_array = ['Shipped',
                             'Out for delivery',
                             'In transit',
                             'On the way']
              next unless state_array.include? order_status.text.strip or order_status.text.strip.include? "Delivered"
              us_tracking_id = scraper.get_tracking_id page
              if us_tracking_id.present?
                ship_log "us_tracking_id[#{us_tracking_id}]"
                us_tracking_ids.push us_tracking_id
              end
            end
            shipment.push_us_tracking_id store, order_id, us_tracking_ids if shipment_divs.count == us_tracking_ids.count
          end
          shipment.save!
        end
        shipment.check_and_ship
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
      Spree::Shipment.
        where(state: ['pending', 'ready']).
        where.not(:state => 'canceled').
        where.not(json_store_order_id: nil).
        where('created_at >= ?', DateTime.new(2014,12,6)).
        find_each do |shipment|
        next if shipment.order.state == 'canceled'
        ship_log "shipment.id:#{shipment.id}"
        ship_log "shipment store_order_id#{shipment.json_store_order_id}"
        if (1.second.ago - shipment.created_at) > 5.days
          send_notify_email "check shipment status", "orderid: #{shipment.order.number} / created_at:#{shipment.created_at}"
        end
        unless shipment.after_shipped_state == 'before_ship'
          shipment.check_ship
        end
        store_order_id = shipment.json_store_order_id
        store_order_id.each do |store, order_ids|
          next if store != 'gap' and store != 'bananarepublic'
          order_ids.each do |order_id|
            ship_log "store:#{store}, order_id:#{order_id}"
            order_status_page = scraper.get_order_page order_id
            raise "order status page not found! store_order_id:#{shipment.id}" if order_status_page == nil
            status = scraper.get_single_text(order_status_page, scraper.selectors['order_status'])
            next if status.nil? or "Shipped" != status.text
            ship_log "status:#{status.text}"
            us_tracking_ids = []
            shipment_status_page = scraper.get_shipment_page order_id
            shipment_divs = scraper.get_multiple_text(shipment_status_page, scraper.selectors['shipping_div'])
            shipment_divs.each do |page|
              us_tracking_id = scraper.get_single_text(page, scraper.selectors['us_tracking_id'])
              raise "couldn't get tracking id from amazon order id#{order_id}" if us_tracking_id.nil?
              ship_log "us_tracking_id[#{us_tracking_id.text.strip}]"
              us_tracking_ids.push us_tracking_id.text.strip
            end
            shipment.push_us_tracking_id store, order_id, us_tracking_ids
          end
        end
        shipment.check_and_ship
      end
    rescue Exception => e
      ship_log "error occured: #{$!}"
      ship_log e.backtrace
      send_error_email e
    end
  end
  desc "shipping status update from packagetrackr"
  task packagetrackr_scraping: :environment do
    begin
      ship_log "start packagetrackr_scraping"
      scraper = Spree::PackagetrackrScraper.new
      Spree::Shipment.
        where(:state => 'shipped').
        where(:after_shipped_state => 'local_delivery').
        where.not(json_store_order_id: nil).
        where('created_at >= ?', DateTime.new(2014,12,6)).
        find_each do |shipment|
        json_us_tracking_id = shipment.json_us_tracking_id
        tracking_id_list = []
        json_us_tracking_id.each do |store, order_ids|
          order_ids.map {|order_id, tracking_ids| tracking_id_list.push tracking_ids}
        end
        tracking_id_list.flatten!
        ship_log "tracking_id_list:#{tracking_id_list}"
        next if tracking_id_list.empty?
        id_count = tracking_id_list.count
        delivered_count = 0
        tracking_id_list.each do |tracking_id|
          ship_log "#{tracking_id}"
          if tracking_id == 'N/A'
            delivered_count += 1
            next
          end
          status = scraper.get_status(tracking_id)
          next if status.nil? or status.text.nil?
          ship_log "#{tracking_id}:#{status.text}"
          delivered_count += 1 if status.present? and (status.text == "Delivered" or status.text == 'Tracking Information Expired')
        end
        shipment.complete_local_delivery if id_count == delivered_count
      end
    rescue Exception => e
      ship_log "error occured: #{$!}"
      ship_log e.backtrace
      send_error_email e
    end
  end
  desc "getting information from theclass"
  task theclass_api_update: :environment do
    begin
      api = Spree::TheclassApi.new
      Spree::Shipment.
        where(after_shipped_state: ['local_delivery', 'local_delivery_complete', 'DC_partially_stocked', 'DC_stocked', 'overseas_delivery', 'customs', 'domestic_delivery']).
        where.not(:state => 'canceled').
        joins(:order).
        where('spree_orders.completed_at > ?', DateTime.new(2015,3,18,11,00).in_time_zone('Seoul'))
        find_each do |shipment|
        if shipment.forwarding_id.nil?
          send_notify_email "forwarding_id is nil", "orderid: #{shipment.order.number} / created_at:#{shipment.created_at}"
          next
        end
        ship_log "processing shipment:#{shipment.id}"
        if (1.second.ago - shipment.created_at) > 10.days
          ship_log "10days passed:#{shipment.id}"
          send_notify_email "check shipment status", "orderid: #{shipment.order.number} / created_at:#{shipment.created_at}"
        end
        status = api.shipment_status shipment
        status = status.try([], 'order_info').try([], 'd_status')
        raise "no return from the class for status check" if status.nil?
        case status
        when "0" #구매대기
        when "1" #배송신청
        when "4" #일부입고
          shipment.partially_complete_DC_stock
        when "5" #입고완료
          shipment.complete_DC_stock
        when "6" #포장완료
          shipment.complete_DC_stock
        when "7" #출고완료
          shipment.start_oversea_delivery
        when "8" #통관진행중
          shipment.complete_oversea_delivery
        when "9" #국내배송중
          shipment.start_domestic_delivery
        when "10" #배송완료
          shipment.complete_domestic_delivery
        else
          ship_log "check status code:#{status}"
          send_notify_email "check shipment status", "orderid: #{shipment.order.number} / created_at:#{shipment.created_at}"
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
      Spree::Shipment.
        where(after_shipped_state: ['local_delivery', 'local_delivery_complete', 'DC_partially_stocked', 'DC_stocked', 'overseas_delivery', 'customs', 'domestic_delivery']).
        where.not(:state => 'canceled').
        where('spree_shipments.created_at >= ?', DateTime.new(2014,12,6)).
        joins(:order).
        where('spree_orders.completed_at < ?', DateTime.new(2015,3,18,11,00).in_time_zone('Seoul'))
        find_each do |shipment|
        if shipment.forwarding_id.nil?
          send_notify_email "forwarding_id is nil", "orderid: #{shipment.order.number} / created_at:#{shipment.created_at}"
          next
        end
        ship_log "processing shipment:#{shipment.id}"
        if (1.second.ago - shipment.created_at) > 10.days
          ship_log "10days passed:#{shipment.id}"
          send_notify_email "check shipment status", "orderid: #{shipment.order.number} / created_at:#{shipment.created_at}"
        end
        page = api.post_shipment_status shipment
        raise "no return from the 82 for status check" if page.nil?
        status = page.xpath(api.xpaths['status']).text.scan(/.{2}/)
        ship_log "status:#{status}"
        if status.include? "OC" #출고완료
          shipment.start_oversea_delivery
        elsif status.include? "IC"
          if status.all?{|st| st == "IC" }
            shipment.complete_DC_stock # 전체입고완료
          else
            shipment.partially_complete_DC_stock # 부분입고완료
          end
        elsif (not status.empty?) and status.all?{|st| st == "RC" } #고객수령완료
          shipment.complete_domestic_delivery
        elsif status.any?{|st| st == "EI" } #오류입고
          ship_log "오류입고"
          send_notify_email "check shipment status:오류입고", "orderid: #{shipment.order.number} / created_at:#{shipment.created_at} / #{page.xpath(api.xpaths['error']).text}"
        else
          ship_log "not matched case"
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
      Spree::Shipment.where(after_shipped_state: ['overseas_delivery', 'customs', 'domestic_delivery']).
        where.not(:state => 'canceled').
        where('created_at >= ?', DateTime.new(2014,12,6)).
        find_each do |shipment|
        if shipment.json_kr_tracking_id.nil?
          send_notify_email "json_kr_tracking_id is nil", "orderid: #{shipment.order.number} / created_at:#{shipment.created_at}"
          next
        end
        if (1.second.ago - shipment.created_at) > 15.days
          send_notify_email "check shipment status", "orderid: #{shipment.order.number} / created_at:#{shipment.created_at}"
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
  desc "shipping status update from foot-locker shipping confirm email"
  task foot_locker_scraping: :environment do
    begin
      ship_log "start foot_locker_scraping"
      scraper = Spree::GmailScraper.new
      raise "Login failed! #{scraper.login_info['userid']}/#{scraper.login_info['password']}" unless scraper.login
      Spree::Shipment.
        where(state: ['pending', 'ready']).
        where.not(:state => 'canceled').
        where.not(json_store_order_id: nil).
        where('created_at >= ?', DateTime.new(2014,12,6)).
        find_each do |shipment|
        next if shipment.order.state == 'canceled'
        ship_log "shipment.id:#{shipment.id}"
        ship_log "shipment store_order_id#{shipment.json_store_order_id}"
        if (1.second.ago - shipment.created_at) > 5.days
          send_notify_email "check shipment status", "orderid: #{shipment.order.number} / created_at:#{shipment.created_at}"
        end
        unless shipment.after_shipped_state == 'before_ship'
          shipment.check_ship
        end
        store_order_id = shipment.json_store_order_id
        store_order_id.each do |store, order_ids|
          next if store != 'footlocker'
          order_ids.each do |order_id|
            query = ['FROM', scraper.addresses['foot_locker_shipment_confirm'],
                     'SINCE', scraper.get_imap_date(-30),
                     'SUBJECT', scraper.subjects['foot_locker_shipment_confirm'],
                     'BODY', order_id]
            uids = scraper.get_uid_list(query)
            next if uids.empty?
            doc = scraper.get_html_doc uids.first
            tracking_id = scraper.get_single_text(doc, scraper.selectors['foot_locker_shipment_confirm_tracking_id'])
            raise "not found tracking id footlocker:#{order_id}" if tracking_id.nil?
            shipment.push_us_tracking_id store, order_id, tracking_id.text.strip
          end
        end
        shipment.check_and_ship
      end
    rescue Exception => e
      ship_log "error occured: #{$!}"
      ship_log e.backtrace
      send_error_email e
    end
  end
  desc "test"
  task tmp_test: :environment do
    api = Spree::TheclassApi.new
    ship = Spree::Order.find_by_number('R400511911').shipments.first
    puts api.shipment_registration ship
  end
end
