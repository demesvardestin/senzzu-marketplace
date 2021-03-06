class StoresController < ApplicationController
    before_action :set_store, except: [:show]
    before_action :authenticate_store!, except: [:show]
    before_action :own_store, except: [:add_to_queue, :mark_fulfilled, :deny_request, :alert_customer]
    
    def go_live
        @store = current_store
        return if @store.nil?
        @store.update(live: true)
        render :layout => false
    end
    
    def verify_store
        begin
            begin
                acct = Stripe::Account.retrieve(current_store.stripe_cus)
            rescue
                acct = Stripe::Account.create(
                    :type => 'custom',
                    :country => 'US',
                    :email => current_store.email
                )
            end
            acct.tos_acceptance.date = Time.now.to_i
            acct.tos_acceptance.ip = guest_shopper.email
            acct.legal_entity.type = 'company'
            data = params[:data]
            acct.external_accounts.create(external_account: data[:token])
            acct.legal_entity.business_name = current_store.name
            acct.legal_entity.address.line1 = current_store.street_address
            acct.legal_entity.address.city = current_store.town
            acct.legal_entity.address.state = current_store.state
            acct.legal_entity.address.postal_code = current_store.zipcode
            acct.legal_entity.business_tax_id = data[:ein]
            acct.legal_entity.dob.day = data[:dob].split('/')[1]
            acct.legal_entity.dob.month = data[:dob].split('/')[0]
            acct.legal_entity.dob.year = data[:dob].split('/')[2]
            acct.legal_entity.first_name = data[:firstName]
            acct.legal_entity.last_name = data[:lastName]
            acct.legal_entity.ssn_last_4 = data[:last_4]
            acct.save
            current_store.update(stripe_cus: acct.id)
            render :layout => false
        rescue Exception => e
            @error = e
            render 'stripe_account_error', :layout => false
        end
    end
    
    def dashboard
        
    end
    
    def inventory
        
    end
    
    def order_history
        @orders = current_store.completed_orders
    end
    
    def item_requests
        @orders = SpecialOrder.where(store_id: current_store.id, denied: false, picked_up: false)
    end
    
    def special_order
        begin
            @order = SpecialOrder.find(params[:special_order][:id])
            @order.update(special_orders_params)
        rescue
            render 'special_order_update_error', :layout => false
            return
        end
        render :layout => false
    end
    
    def alert_customer
        @order = SpecialOrder.find(params[:id])
        @store = Store.find_by(id: @order.store_id)
        @message = "Hi, Senzzu here! Wanted to update you on the special order request you had placed to #{@store.name} on #{@order.created_at.strftime('%m/%d/%y')}. It is now available for pickup!"
        MessageUpdate.alert_customer(@order.shopper_phone, @message)
    end
    
    def mark_fulfilled
        @order = SpecialOrder.find(params[:id])
        @order.update(picked_up: true)
    end
    
    def deny_request
        id = params[:id]
        @order = SpecialOrder.find_by(id: id)
        @order.update(denied: true)
        @store = Store.find_by(id: @order.store_id)
        @message = "Hi, Senzzu here! Unfortunately, the special order request you had placed to #{@store.name} on #{@order.created_at.strftime('%m/%d/%y')} cannot be fulfilled. It may be available at other stores on senzzu.com!"
        MessageUpdate.alert_customer(@order.shopper_phone, @message)
    end
    
    def add_to_queue
        id = params[:id]
        SpecialOrder.find_by(id: id).update(pending: true)
        ## Text customer
    end
    
    def add_data_to_firestore
        @store = current_store
        data = params["data"]
        @type = data["type"]
        @doc_id = data["doc_id"]
        @url = data["url"]
        @status = data["status"].downcase if data["status"]
        if @status == "in preparation"
            @status_level = 1
        else
            @status_level = 2
        end
        @order_count = current_store.unprocessed_orders.count
        if data.length > 1
            @name = data["name"]
            @ndc = data["ndc"]
            @price = data["price"]
            @strength = data["strength"]
            @available_sizes = data["available_sizes"]
            @available_prices = data["available_prices"]
            @size = data["size"]
            @taxable = data["taxable"]
            @description = data["description"]
            @category = data["category"]
        end
        render :layout => false 
    end
    
    def update_unprocessed_orders_count
        @count = current_store.unprocessed_orders.count
        @unprocessed = params[:count]
        render :layout => false
    end
    
    def update_item_requests_count
        @orders = SpecialOrder.all.where(store_id: current_store.id, denied: false, picked_up: false)
        @count = @orders.count
        @current = params[:count]
        render :layout => false
    end
    
    def remove_data_from_firestore
        @store = current_store
        data = params["data"]
        @type = data["type"]
        @id = data["id"]
        render :layout => false 
    end
    
    def read_data_from_firestore
        @store = current_store
        @order_count = @store.unprocessed_orders.count
        data = params["data"]
        @type = data["type"]
        render :layout => false 
    end
    
    def store_banner_image
        @store = current_store
        return if @store.nil?
        url = params[:data][:url]
        current_store.update(banner_image: url)
        render :layout => false
    end
    
    def reload_stats
        @new = current_store.unprocessed_orders.count
        @processed = current_store.completed_orders.count
        @earnings = current_store.all_orders.sum(&:total_cost).round(2)
        render :layout => false 
    end
    
    def add_new_item
    end
    
    def earnings
        if current_store.has_a_bank_account
            @balance = Stripe::Balance.retrieve(
              {:stripe_account => current_store.stripe_cus}
            )
        end
        @payments = current_store.all_orders.reverse[0..19]
        @payments_length = current_store.all_orders.count
        if @payments_length > 20
            @results = 20
        else
            @results = @payments.length
        end
    end
    
    def retrieve_earnings
        @start = params[:start]
        @_end = params[:end]
        @payments_length = current_store.all_orders.count
        if (@payments_length - @start.to_i) > 20
            @results = 20
        else
            @results = (@payments_length - @start.to_i)
        end
        @payments = current_store.all_orders.reverse[@start.to_i..@_end.to_i]
        render :layout => false
    end
    
    def interval_analytics
        @store = current_store
        return if @store.nil?
        @interval = params[:interval]
        render :layout => false
    end
    
    def show
        @store = Store.find(params[:id])
        @order = SpecialOrder.new
    end
    
    def edit_profile
        
    end
    
    def edit_banner
        
    end
    
    def edit_hours
        
    end
    
    def update
        @store.update(stores_params)
        render :layout => false
    end
    
    def update_store
        @store = current_store
        return if @store.nil?
        @store.update(firestore_doc_id: params[:firestore_doc_id])
        render :layout => false
    end
    
    def update_order
        @store = current_store
        return if @store.nil?
        @order = Order.where('store_id = ? AND confirmation = ?', @store.id, params[:data][:confirmation]).first
        @status = params[:data][:status]
        if @status == "order ready"
            if @order.delivery_option.downcase == "delivery"
                @message = "Great news! Your order is now on the way!"
            else
                @message = "Great news! Your order is ready to be picked up!"
            end
            @order.update(status: @status, processed: true)
            MessageUpdate.alert_customer(@order.phone_number, @message)
        else
            @message = "Hey there, just wanted to let you know that your order is in preparation and should be ready soon!"
            MessageUpdate.alert_customer(@order.phone_number, @message)
            @order.update(status: @status)
        end
        render :layout => false
    end
    
    def update_sessions_count
        sessions_count =  @store.sessions_count
        @store.update(sessions_count: sessions_count + 1)
    end
    
    private
    
    def set_store
        @store = current_store
    end
    
    def own_store
        set_store
        id = params[:id]
        return if !id || !@store
        redirect_to root_path if @store.id.to_s != id
    end
    
    def stores_params
        params.require(:store).permit(:email, :street_address, :town, :state, :zipcode, :name, :phone, :supervisor, :website, :opening_weekday,
                                    :closing_weekday, :opening_saturday, :closing_saturday, :opening_sunday, :closing_sunday, :delivery_fee, :banner_image,
                                    :delivery_minimum) 
    end
    
    def order_params
        params.require(:order).permit(:total, :details, :order_type, :status, :additional_details, :confirmation, :delivery_address, :delivery_phone,
                                    :delivery_phone, :delivery_name, :pickup_contact, :pickup_time, :store_id, :shopper_id) 
    end
    
    def special_orders_params
        params.require(:special_order).permit(:item_name, :item_size, :item_description, :item_price, :availability_date) 
    end
end