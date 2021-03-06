module ApplicationHelper
    
    def navbar
        if current_store
            return 'layouts/store_navbar'
        elsif current_admin
            return 'layouts/admin_navbar'
        end
        if request.original_url.include?('/blog')
            'layouts/blog_navbar'
        else
            'layouts/main_navbar'
        end
    end
    
    def checkout_link
        "/#{current_cart.id}/checkout?cart_id=#{@token}&shopper=true&guest=false&senzzu_token=#{guest_shopper.email}" 
    end
    
    def body
        current_store ? 'layouts/store_body' : 'layouts/main_body'
    end
    
    def footer
        current_store ? 'stores/footer' : 'layouts/footer'
    end
    
    def current_cart
        @cart = Cart.where(shopper_email: guest_shopper.email, pending: true).last
        if @cart.nil?
            @cart = Cart.create(shopper_email: guest_shopper.email, pending: true)
        end
        return @cart
    end
    
    def logistics_details_for(store)
        store.delivery_minimum
        # if !store.has_a_bank_account
        #     'Delivery & Pickup (cash/card)'
        # else
        #     'Delivery & Pickup'
        # end
    end
    
    def banner_path
        'https://s3.us-east-2.amazonaws.com/senzzu/banner.jpg' 
    end
    
    def item_categories
        ['skin-care', 'baby-care', 'hair-care', 'dental-care', 'cold-relief', 'pain-relief', 'fever-reducers', 'personal-care', 'toiletries', "women's hygiene",
        "anti-diahrreal", 'allergy-relief', 'anti-bacterial', 'household items', 'vitamins & supplements', 'and more!'] 
    end
    
    def unescape(content)
        URI.unescape(content)
    end
    
    def encode(string)
        URI.encode(string)
    end
    
    def decode(string)
        URI.decode(string)
    end
    
    def featured_article
        ## Placeholder until we figure out how to select a feature article
        Article.last
    end
    
end
