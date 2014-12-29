Spree::Shipment.class_eval do
  scope :before_ship,             -> { with_state('before_ship') }
  scope :local_delivery,          -> { with_state('local_delivery') }
  scope :local_delivery_complete, -> { with_state('local_delivery_complete') }
  scope :DC_partially_stocked,    -> { with_state('DC_partially_stocked') }
  scope :DC_stocked,              -> { with_state('DC_stocked') }
  scope :overseas_delivery,       -> { with_state('overseas_delivery') }
  scope :customs,                 -> { with_state('customs') }
  scope :domestic_delivery,       -> { with_state('domestic_delivery') }
  scope :delivered,               -> { with_state('delivered') }

  state_machine   :after_shipped_state,   :initial  => :before_ship do

    before_transition :from => :before_ship, :do => :check_ship
    #after_transition :from => :before_ship, :do => :shipment_registration

    event :complete_ship do
      transition from: :before_ship, to: :local_delivery
    end
    event :complete_local_delivery do
      transition from: [:before_ship, :local_delivery], to: :local_delivery_complete
    end
    event :partially_complete_DC_stock do
      transition from: [:before_ship, :local_delivery, :local_delivery_complete], to: :DC_partially_stocked
    end
    event :complete_DC_stock do
      transition from: [:before_ship, :local_delivery, :local_delivery_complete, :DC_partially_stocked], to: :DC_stocked
    end
    event :start_oversea_delivery do
      transition from: [:before_ship, :local_delivery, :local_delivery_complete, :DC_partially_stocked, :DC_stocked], to: :overseas_delivery
    end
    event :complete_oversea_delivery do
      transition from: [:before_ship, :local_delivery, :local_delivery_complete, :DC_partially_stocked, :DC_stocked, :overseas_delivery], to: :customs
    end
    event :start_domestic_delivery do
      transition from: [:before_ship, :local_delivery, :local_delivery_complete, :DC_partially_stocked, :DC_stocked, :overseas_delivery, :customs], to: :domestic_delivery
    end
    event :complete_domestic_delivery do
      transition from: [:before_ship, :local_delivery, :local_delivery_complete, :DC_partially_stocked, :DC_stocked, :overseas_delivery, :customs, :domestic_delivery], to: :delivered
    end
  end   #state_machine

  def check_ship
    Rails.logger.info "shipping-update shipment[#{self.id}] state[#{self.state}]"
    if self.state != 'shipped' and self.state != 'canceled'
      self.order.payments.each do |p|
        Rails.logger.info "shipping-update payment[#{p.id}] state[#{p.state}]"
        begin
          p.capture! if p.state == 'pending'
        rescue Exception => e
          Rails.logger.info "shipping-update capture failed![#{e}]"
        end
      end
      self.reload
      Rails.logger.info "shipping-update state #{self.state}"
      if self.state == 'ready'
        Rails.logger.info "shipping-update it's ready to ship"
      else
        Rails.logger.info "shipping-update force to update to ready"
        self.update_columns(state: 'ready')
      end
      return self.ship!
    end
    true
  end

  def shipment_registration
    return if self.json_store_order_id.nil?
    api = Spree::The82Api.new
    page = api.post_shipment_registration self
    Rails.logger.info "shipping-update:#{page.to_json}"
    forwarding_id = page['warehouseordno']
    kr_tracking_id = page['transnum']
    self.update_columns(forwarding_id: forwarding_id)
    self.update_columns(json_kr_tracking_id: kr_tracking_id)
  end

  def after_ship
    inventory_units.each &:ship!
    send_shipped_email
    touch :shipped_at
    update_order_shipment_state
    self.complete_ship!
  end

  def all_shipped?
    return false if self.json_store_order_id.nil?
    store_count = self.json_store_order_id.count
    failed_count = 0
    self.json_store_order_id.each do |store, order_ids|
      if order_ids.first == "FAILED"
        failed_count += 1
      end
      next unless ['gap','bananarepublic','amazon'].include? store
      return false if self.json_us_tracking_id.nil? or self.json_us_tracking_id.empty?
      return false if self.json_us_tracking_id[store].nil? or self.json_us_tracking_id[store].empty?
      order_ids.each do |order_id|
        return false if self.json_us_tracking_id[store][order_id].nil? or self.json_us_tracking_id[store][order_id].empty?
      end
    end
    return false if store_count == failed_count
    true
  end

  def push_store_order_id store, order_id
    store_order_id = self.json_store_order_id
    us_tracking_id = self.json_us_tracking_id
    store_order_id = {} if store_order_id.nil?
    us_tracking_id = {} if us_tracking_id.nil?
    if store_order_id[store].nil?
      store_order_id[store] = []
      us_tracking_id[store] = {}
    end
    store_order_id[store].push order_id
    store_order_id[store].flatten!
    store_order_id[store].uniq!
    store_order_id[store].each do |id|
      next if id == "FAILED"
      us_tracking_id[store][id] = [] if us_tracking_id[store][id].nil?
    end
    self.update_columns(:json_store_order_id => store_order_id)
    self.update_columns(:json_us_tracking_id => us_tracking_id)
  end
  def push_us_tracking_id store, order_id, us_tracking_ids
    return if store.nil? or order_id.nil? or us_tracking_ids.nil?
    us_tracking_id_array = []
    us_tracking_id_array.push us_tracking_ids
    us_tracking_id_array.flatten!
    us_tracking_id = self.json_us_tracking_id
    us_tracking_id = {} if us_tracking_id.nil?
    us_tracking_id[store] = {} if us_tracking_id[store].nil?
    us_tracking_id[store][order_id] = [] if us_tracking_id[store][order_id].nil?
    us_tracking_id[store][order_id] = us_tracking_id_array
    self.update_columns(:json_us_tracking_id => us_tracking_id)
  end
  def get_store_urls
    return [] if self.store.nil?
    urls = []
    self.store.split(",").each do |store|
      case store
      when 'amazon'
        urls.push 'www.amazon.com'
      when 'ssense'
        urls.push 'www.ssense.com'
      when 'gap'
        urls.push 'www.gap.com'
      when 'bananarepublic'
        urls.push 'www.bananarepublic.com'
      else
        urls.push store
      end
    end
    urls
  end

  def get_shipment_status
    if self.canceled? or self.order.canceled?
      return "canceled"
    elsif self.order.state == "returned"
       return "returned"
    else
       return self.after_shipped_state
    end
  end

end   #class_eval
