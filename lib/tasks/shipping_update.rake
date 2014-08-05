
namespace :shipping_update do
  def send_notify_email exception
    Spree::NotifyMailer.notify_email('failed to update shipping status', exception.backtrace).deliver
  end

  desc "shipping status update from amazon shipping confirm email"
  task amz_shipping_scraping: :environment do
    begin
    scraper = Spree::GmailScraper.new
    raise "amz_shipping_scraping: Login failed! #{scraper.login_info['userid']}/#{scraper.login_info['password']}" unless scraper.login(scraper.login_info['userid'], scraper.login_info['password'])

    #amazon shipping confirm
    query = ['FROM', scraper.addresses['amz_shipping_confirm'],
             'SINCE', scraper.get_imap_date(-30)]
    last_processed_shipment_email = Spree::Shipment.where.not(state: 'shipped').order('shipment_confirm_email_uid DESC').first.shipment_confirm_email_uid
    last_processed_shipment_email = 0 if last_processed_shipment_email == nil
    uids = scraper.get_uid_list(query).find_all { |uid| uid > last_processed_shipment_email }
    return if uids == nil 
    uids.each do |uid|
      doc = scraper.get_html_doc uid
      continue if doc == nil
      store_order_id = scraper.get_single_text(doc, scraper.selectors['amz_shipping_confirm'])
      raise "amz_shipping_scraping: not found order id from amazon shipping email" if store_order_id == nil
      shipments = Spree::Shipment.where(store: 'amazon').where(store_order_id: store_order_id.text)

      #below test causes too many errors
      #raise "amz_shipping_scraping: not found shipment" if shipments == nil
      shipments.each { |shipment|
        shipment.shipment_confirm_email_uid = uid
        shipment.ship!
      }
    end
    rescue Exception => e
      Rails.logger.error "error occured: #{$!}"
      Rails.logger.error e.backtrace
      send_notify_email e
    end
  end

  desc "shipping status update from package tracker email"
  task package_tracker_scraping: :environment do
    begin
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
      continue if doc == nil
      order_id = scraper.get_single_text(doc, scraper.selectors['package_tracker_confirm']).text
      raise "not found order id from amazon shipping email" if order_id == nil
      shipments = Spree::Shipment.where(store: 'amazon').where(number: order_id) unless order_id.length == 0

      #below test causes too many errors
      #raise "not found shipment" if shipment == nil
      continue if shipments == nil
      shipments.each { |shipment|
        shipment.shipment_confirm_email_uid = uid
        shipment.complete_local_delivery
        shipment.save
      }
    end
    rescue Exception => e
      Rails.logger.error "error occured: #{$!}"
      Rails.logger.error e.backtrace
      send_notify_email e
    end
  end

  desc "shipping status update from ohmyzip web-page"
  task ohmyzip_scraping: :environment do
    begin
      #scraping from ohmyzip
      scraper = Spree::OhmyzipScraper.new
      raise "Login failed!" unless scraper.login(scraper.login_info['userid'], scraper.login_info['password'])

      order_list_page = scraper.get_html_doc scraper.addresses['order_list']
      raise "order list page not found" if order_list_page == nil
      scraper.get_multiple_text(order_list_page, scraper.selectors['order_list_row']).each do |row|
        shipment_id_doc = scraper.get_single_text(row, scraper.selectors['order_list_shipment_id'])
        tracking_id_doc = scraper.get_single_text(row, scraper.selectors['order_list_tracking_id'])
        unless shipment_id_doc == nil
          @shipment_id = shipment_id_doc.text
          @tracking_id = tracking_id_doc.text unless tracking_id_doc == nil
          order_detail_doc = scraper.get_html_doc(scraper.addresses['order_detail'] + @shipment_id)
          raise "order detail page not found" if order_detail_doc == nil
          store_doc = scraper.get_single_text(order_detail_doc, scraper.selectors['order_detail_store'])
          store_order_id_doc = scraper.get_single_text(order_detail_doc, scraper.selectors['order_detail_store_order_id'])
          if store_doc == nil or store_order_id_doc == nil
            raise "scraping error order detail"
          else
            store = store_doc.text
            store_order_id = store_order_id_doc.text
          end
          shipments = Spree::Shipment.where(store: store).where(store_order_id: store_order_id)

          #raise "shipments not found" if shipments == nil
          shipments.each do |shipment|
            unless shipment.after_shipped_state == :overseas_delivery
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
      send_notify_email e
    end
  end

  desc "shipping status update from warpex tracker page"
  task warpex_scraping: :environment do
    begin
      scraper = Spree::WarpexScraper.new
      Spree::Shipment.where.not(tracking_id: nil).where.not(after_shipped_state: :delivered).each do |shipment|
        tracking_page = scraper.addresses['tracking_page'] + shipment.tracking_id
        doc = scraper.get_html_doc tracking_page
        raise "tracking_page not found" if doc == nil
        img = scraper.get_single_text doc, scraper.selectors['status']
        case img['src']
        when scraper.status['step3']
          shipment.complete_oversea_delivery
        when scraper.status['step4']
        when config['tracking_page_step4']
          shipment.start_domestic_delivery
        when scraper.status['step5']
          shipment.complete_domestic_delivery
        else
          if img['src'] != craper.status['step1']  and img['src'] != craper.status['step2']
            raise "scraping error"
          end
        end
        shipment.save
      end
    rescue Exception => e
      Rails.logger.error "error occured: #{$!}"
      Rails.logger.error e.backtrace
      send_notify_email e
    end
  end

  desc "store html documents getting from ohmyzip"
  task store_ohmyzip_page: :environment do
    scraper = Spree::OhmyzipScraper.new
    warpex_scraper = Spree::WarpexScraper.new
    raise "login failed" unless  scraper.login(scraper.login_info['userid'], scraper.login_info['password'])

    doc = scraper.get_html_doc scraper.addresses['order_list']
    file = File.open("#{Rails.root}/spec/resource/ohmyzip_order_list_page.html", "w")
    file.puts doc.to_html

    scraper.get_multiple_text(doc, scraper.selectors['order_list_row']).each do |partial|
      shipment_id = scraper.get_single_text(partial, scraper.selectors['order_list_shipment_id'])
      tracking_id = scraper.get_single_text(partial, scraper.selectors['order_list_tracking_id'])
      unless shipment_id == nil and tracking_id == nil
        @order_detail_address = scraper.addresses['order_detail'] + shipment_id.text
        @tracking_page_address = warpex_scraper.addresses['tracking_page'] + tracking_id.text
        break
      end
    end

    #store order detail page
    doc = scraper.get_html_doc @order_detail_address
    file = File.open("#{Rails.root}/spec/resource/ohmyzip_order_detail_page.html", "w")
    file.puts doc.to_html

    #store tracking page
    doc = scraper.get_html_doc @tracking_page_address
    file = File.open("#{Rails.root}/spec/resource/tracking_page.html", "w")
    file.puts doc.to_html
  end

  desc "store shipping-confirm email"
  task store_shipping_email: :environment do

    scraper = Spree::GmailScraper.new
    raise "login failed" unless  scraper.login(scraper.login_info['userid'], scraper.login_info['password'])

    query = ['FROM', scraper.addresses['amz_shipping_confirm'],
             'SINCE', scraper.get_imap_date(-30)]
    uids = scraper.get_uid_list query

    file = File.open("#{Rails.root}/spec/resource/amazon_shipping_confirm.html", "w")
    uids.each { |uid|
      doc = scraper.get_html_doc(uid)
      unless doc == nil
        file.puts doc.to_html
        break
      end
    }
  end

  desc "store order-confirm email"
  task store_order_email: :environment do

    scraper = Spree::GmailScraper.new
    raise "login failed" unless  scraper.login(scraper.login_info['userid'], scraper.login_info['password'])

    query = ['FROM', scraper.addresses['amz_order_confirm'],
             'SINCE', scraper.get_imap_date(-30)]
    uids = scraper.get_uid_list query

    file = File.open("#{Rails.root}/spec/resource/amazon_order_confirm.html", "w")
    uids.each { |uid|
      doc = scraper.get_html_doc(uid)
      unless doc == nil
        file.puts doc.to_html
        break
      end
    }
  end

  desc "store packagetracker-confirm email"
  task store_packagetracker_email: :environment do

    scraper = Spree::GmailScraper.new
    raise "login failed" unless  scraper.login(scraper.login_info['userid'], scraper.login_info['password'])

    query = ['FROM', scraper.addresses['package_tracker_confirm'],
             'SINCE', scraper.get_imap_date(-30)]
    uids = scraper.get_uid_list query

    file = File.open("#{Rails.root}/spec/resource/package_tracker_confirm.html", "w")
    uids.each { |uid|
      doc = scraper.get_html_doc(uid)
      unless doc == nil
        file.puts doc.to_html
        break
      end
    }
  end

end
