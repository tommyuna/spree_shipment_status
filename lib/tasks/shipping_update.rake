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
        where(state: ['pending', 'ready']).
        where.not(:state => 'canceled').
        where.not(json_store_order_id: nil).
        where('created_at >= ?', DateTime.new(2014,12,6)).
        find_each do |shipment|

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
            addr = "#{scraper.addresses['order_status']}#{order_id}"
            ship_log "addr:#{addr}"
            order_status_page = scraper.get_html_doc addr
            raise "order status page not found! store_order_id:#{shipment.id}" if order_status_page == nil
            us_tracking_ids = []
            shipment_divs = scraper.get_multiple_text(order_status_page, scraper.selectors['shipping_div'])
            ship_log "shipment_divs:#{shipment_divs.count}"
            shipment_divs.each do |page|
              order_status = page.at_css(scraper.selectors['shipping_status']).text.strip
              raise "couldn't get order status in amazon! store_order_id:#{id}" if order_status.nil?
              ship_log "order_status:[#{order_status}]"
              state_array = ['Shipped',
                             'Delivered',
                             'Delivered today',
                             'Out for delivery',
                             'In transit',
                             'Arriving today',
                             'Arriving tomorrow']
              next unless state_array.include? order_status
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
        if shipment.all_shipped?
          begin
            ship_log "shipped[#{shipment.id}]"
            shipment.complete_ship
            shipment.shipment_registration
            shipment.save
          rescue Exception => e
            ship_log "failed!!! shipmentid[#{shipment.id}]"
            ship_log "failed!!![#{e}]"
          end
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
      Spree::Shipment.
        where(state: ['pending', 'ready']).
        where.not(:state => 'canceled').
        where.not(json_store_order_id: nil).
        where('created_at >= ?', DateTime.new(2014,12,6)).
        find_each do |shipment|
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
        if shipment.all_shipped?
          begin
            ship_log "shipped[#{shipment.id}]"
            shipment.complete_ship
            shipment.shipment_registration
            shipment.save
          rescue Exception => e
            ship_log "failed!!![#{shipment.id}]"
            ship_log "failed!!![#{e}]"
          end
        end
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

  desc "getting information from the82"
  task the82_api_update: :environment do
    begin
      api = Spree::The82Api.new
      Spree::Shipment.
        where(after_shipped_state: ['local_delivery', 'local_delivery_complete', 'overseas_delivery', 'customs', 'domestic_delivery']).
        where.not(:state => 'canceled').
        where('created_at >= ?', DateTime.new(2014,12,6)).
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
        elsif status.all?{|st| st == "RC" } #고객수령완료
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
  desc "shipping status update from amazon shipping confirm email"
  task amz_shipping_scraping: :environment do
    begin
    ship_log "start amz_shipping_scraping"
    scraper = Spree::GmailScraper.new
    raise "amz_shipping_scraping: Login failed! #{scraper.login_info['userid']}/#{scraper.login_info['password']}" unless scraper.login(scraper.login_info['userid'], scraper.login_info['password'])

    #amazon shipping confirm
    query = ['FROM', scraper.addresses['amz_shipping_confirm'],
             'SINCE', scraper.get_imap_date(-30)]
    last_processed_shipment_email = Spree::Shipment.where.not(shipment_confirm_email_uid: nil).order('shipment_confirm_email_uid DESC').first.shipment_confirm_email_uid
    last_processed_shipment_email = 0 if last_processed_shipment_email == nil
    uids = scraper.get_uid_list(query).find_all { |uid| uid > last_processed_shipment_email - 30 }
    ship_log "last_processed_shipment_email[#{last_processed_shipment_email}]"
    uids.each do |uid|
      ship_log "#{uid}:-------------------------------------------------"
      doc = scraper.get_html_doc uid
      next if doc == nil
      store_order_id = scraper.get_multiple_text(doc, scraper.selectors['amz_shipping_confirm'])
      raise "amz_shipping_scraping: not found order id from amazon shipping email" if store_order_id.empty?
      store_order_id.each do |order_id|
        @amazon_id = nil
        if order_id.text =~ /\d{3}-\d{7}-\d{7}*/
          @amazon_id = order_id.text.slice(0, 19)
        else
          next
        end
        ship_log "amazon order id[#{@amazon_id}]"
        shipments = Spree::Shipment.where(store: 'amazon').where(store_order_id: @amazon_id)
        shipments.each { |shipment|
          unless shipment.state == 'shipped' or shipment.state == 'canceled'
            ship_log "shipment:[#{shipment.id}] is updated"
            shipment.shipment_confirm_email_uid = uid
            shipment.complete_ship
            shipment.save
          end
        }
      end
    end
    rescue Exception => e
      Rails.logger.error "error occured: #{$!}"
      Rails.logger.error e.backtrace
      send_error_email e
    end
  end

  desc "shipping status update from package tracker email"
  task package_tracker_scraping: :environment do
    begin
    ship_log "start package_tracker_scraping"
    scraper = Spree::GmailScraper.new
    raise "Login failed!" unless scraper.login(scraper.login_info['userid'], scraper.login_info['password'])

    # Packagetrackr email
    query = ['FROM', scraper.addresses['package_tracker_confirm'],
             'SINCE', scraper.get_imap_date(-30)]
    last_processed_shipment_email = Spree::Shipment.where(after_shipped_state: 'local_delivery').order('shipment_confirm_email_uid DESC').first.shipment_confirm_email_uid
    last_processed_shipment_email = 0 if last_processed_shipment_email == nil
    uids = scraper.get_uid_list(query).find_all { |uid| uid > last_processed_shipment_email }
    return if uids == nil
    uids.each do |uid|
      doc = scraper.get_html_doc uid
      next if doc == nil
      order_id = scraper.get_single_text(doc, scraper.selectors['package_tracker_confirm']).text
      raise "not found order id from amazon shipping email" if order_id == nil
      shipments = Spree::Shipment.where(store: 'amazon').where(number: order_id) unless order_id.length == 0

      #below test causes too many errors
      #raise "not found shipment" if shipment == nil
      next if shipments == nil
      shipments.each { |shipment|
        shipment.shipment_confirm_email_uid = uid
        shipment.complete_local_delivery
        shipment.save
      }
    end
    rescue Exception => e
      Rails.logger.error "error occured: #{$!}"
      Rails.logger.error e.backtrace
      send_error_email e
    end
  end

  desc "shipping status update from ohmyzip web-page"
  task ohmyzip_scraping: :environment do
    begin
      #scraping from ohmyzip
      scraper = Spree::OhmyzipScraper.new
      ship_log "start ohmyzip_scraping #{scraper.login_info['userid']}/#{scraper.login_info['password']}"
      raise "Login failed!" unless scraper.login(scraper.login_info['userid'], scraper.login_info['password'])
      ship_log "ohmyzip login!"
      order_list_page = scraper.get_html_doc scraper.addresses['order_list']
      raise "order list page not found" if order_list_page == nil
      scraper.get_multiple_text(order_list_page, scraper.selectors['order_list_row']).each do |row|
        shipment_id_doc = scraper.get_single_text(row, scraper.selectors['order_list_shipment_id'])
        tracking_id_doc = scraper.get_single_text(row, scraper.selectors['order_list_tracking_id'])
        unless shipment_id_doc == nil
          @shipment_id = shipment_id_doc.text
          @tracking_id = tracking_id_doc.text unless tracking_id_doc == nil
          ship_log "shipment id:#{@shipment_id}/ tracking id:#{@tracking_id}"
          order_detail_doc = scraper.get_html_doc(scraper.addresses['order_detail'] + @shipment_id)
          raise "order detail page not found" if order_detail_doc == nil
          store_doc = scraper.get_single_text(order_detail_doc, scraper.selectors['order_detail_store'])
          store_order_id_doc = scraper.get_single_text(order_detail_doc, scraper.selectors['order_detail_store_order_id'])
          if store_doc == nil or store_order_id_doc == nil
            raise "scraping error order detail#{scraper.addresses['order_detail'] + @shipment_id}"
          else
            store = store_doc.text
            store_order_id = store_order_id_doc.text.split(',')
            ship_log "#{store}/#{store_order_id}"
          end
          case store
          when 'www.amazon.com'
            store = 'amazon'
          when 'www.ssense.com'
            store = 'ssense'
          when 'www.gap.com'
            store = 'gap'
          when 'www.bananarepublic.gap.com'
            store = 'bananarepublic'
          end
          ship_log "store: #{store}"
          shipments = Spree::Shipment.where(store: store).where('store_order_id in (?)', store_order_id)

          #raise "shipments not found" if shipments == nil
          shipments.each do |shipment|
            ship_log "shipment id: #{shipment.id}"
            ship_log "ohmyzip id: #{@shipment_id}"
            ship_log "tracking id: #{@tracking_id}"
            unless shipment.after_shipped_state == 'overseas_delivery' or shipment.state == 'canceled'
              shipment.start_oversea_delivery
              shipment.ohmyzip_id = @shipment_id
              shipment.tracking_id = @tracking_id
              shipment.save
            end
          end
        end
      end
    rescue Exception => e
      Rails.logger.error "error occured: #{$!}"
      Rails.logger.error e.backtrace
      send_error_email e
    end
  end

  desc "shipping status update from warpex tracker page"
  task warpex_scraping: :environment do
    begin
      ship_log "start warpex_scraping"
      scraper = Spree::WarpexScraper.new
      Spree::Shipment.where.not(tracking_id: nil).where.not(after_shipped_state: [:delivered, :canceled]).each do |shipment|
        ship_log "shipment #{shipment.id}"
        next if shipment.state == 'canceled'
        tracking_page = scraper.addresses['tracking_page'] + shipment.tracking_id
        ship_log "tracking_page #{tracking_page}"
        doc = scraper.get_html_doc tracking_page
        raise "tracking_page not found" if doc == nil
        img = scraper.get_single_text doc, scraper.selectors['status']
        ship_log "img:#{img['src']}"
        case img['src']
        when scraper.status['step3']
          shipment.complete_oversea_delivery
        when scraper.status['step4']
          shipment.start_domestic_delivery
        when scraper.status['step5']
          shipment.complete_domestic_delivery
        else
          if img['src'] != scraper.status['step1']  and img['src'] != scraper.status['step2'] and img['src'] != "/images/tracking/track_step.gif"
            raise "scraping error:image source#{img['src']}"
          end
        end
        shipment.save
        ship_log "shipment:#{shipment.after_shipped_state}"
      end
    rescue Exception => e
      Rails.logger.error "error occured: #{$!}"
      Rails.logger.error e.backtrace
      send_error_email e
    end
  end
  desc "test"
  task tmp_test: :environment do
    shipment = Spree::Shipment.find(3692)
    api = Spree::The82Api.new
    page = api.post_shipment_registration shipment
    puts page
  end
end
