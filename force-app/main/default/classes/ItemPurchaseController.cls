public with sharing class ItemPurchaseController {

    public class CartItem {
        @AuraEnabled public Id itemId { get; set; }
        @AuraEnabled public Decimal quantity { get; set; }
        @AuraEnabled public Decimal unitPrice { get; set; }
    }

    @AuraEnabled(cacheable=true)
    public static Account getAccountDetails(Id accountId) {
        if (accountId == null) {
            throw new AuraHandledException('Account ID cannot be null.');
        }
        return [SELECT Id, Name, AccountNumber, Industry FROM Account WHERE Id = :accountId LIMIT 1];
    }

    @AuraEnabled(cacheable=false)
    public static List<Item__c> getItems(String searchKey, String familyFilter, String typeFilter) {
        String query = 'SELECT Id, Name, Description__c, Type__c, Family__c, Image__c, Price__c, AvailableQuantity__c FROM Item__c WHERE Id != null';
        Map<String, Object> params = new Map<String, Object>();
        
        if (String.isNotBlank(searchKey)) {
            String likeKey = '%' + searchKey + '%';
            query += ' AND (Name LIKE :likeKey OR Description__c LIKE :likeKey)';
            params.put('likeKey', likeKey);
        }
        if (String.isNotBlank(familyFilter)) {
            query += ' AND Family__c = :familyFilter';
            params.put('familyFilter', familyFilter);
        }
        if (String.isNotBlank(typeFilter)) {
            query += ' AND Type__c = :typeFilter';
            params.put('typeFilter', typeFilter);
        }
        
        query += ' ORDER BY Name ASC';
        
        return Database.queryWithBinds(query, params, AccessLevel.USER_MODE);
    }

    @AuraEnabled(cacheable=true)
    public static Boolean isCurrentUserManager() {
        List<User> users = [SELECT IsManager__c FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        return !users.isEmpty() && users[0].IsManager__c == true;
    }

    @AuraEnabled
    public static Id checkoutCart(Id accountId, String cartItemsJson) {
        if (accountId == null) {
            throw new AuraHandledException('Account ID is required.');
        }
        if (String.isBlank(cartItemsJson)) {
            throw new AuraHandledException('Cart items are required.');
        }
        
        List<CartItem> cartItems = (List<CartItem>) JSON.deserialize(cartItemsJson, List<CartItem>.class);
        if (cartItems.isEmpty()) {
            throw new AuraHandledException('Cart is empty.');
        }

        Set<Id> itemIds = new Set<Id>();
        for (CartItem ci : cartItems) {
            itemIds.add(ci.itemId);
        }

        // Lock item rows to prevent concurrency issues
        Map<Id, Item__c> itemsMap = new Map<Id, Item__c>([
            SELECT Id, Name, AvailableQuantity__c, Price__c 
            FROM Item__c 
            WHERE Id IN :itemIds 
            FOR UPDATE
        ]);

        for (CartItem ci : cartItems) {
            Item__c item = itemsMap.get(ci.itemId);
            if (item == null) {
                throw new AuraHandledException('Item does not exist.');
            }
            Decimal requested = ci.quantity;
            Decimal available = item.AvailableQuantity__c != null ? item.AvailableQuantity__c : 0;
            if (available < requested) {
                throw new AuraHandledException('Insufficient stock for item: ' + item.Name + '. Available: ' + available + ', Requested: ' + requested);
            }
        }

        // Create Purchase record
        Purchase__c purchase = new Purchase__c(
            ClientId__c = accountId
        );
        insert purchase;

        List<PurchaseLine__c> linesToInsert = new List<PurchaseLine__c>();
        List<Item__c> itemsToUpdate = new List<Item__c>();

        for (CartItem ci : cartItems) {
            Item__c item = itemsMap.get(ci.itemId);
            
            // Deduct stock
            item.AvailableQuantity__c -= ci.quantity;
            itemsToUpdate.add(item);

            // Create purchase line
            linesToInsert.add(new PurchaseLine__c(
                PurchaseId__c = purchase.Id,
                ItemId__c = ci.itemId,
                Amount__c = ci.quantity,
                UnitCost__c = ci.unitPrice != null ? ci.unitPrice : item.Price__c
            ));
        }

        update itemsToUpdate;
        insert linesToInsert;

        return purchase.Id;
    }

    @AuraEnabled
    public static Item__c createNewItem(Item__c item) {
        if (item == null) {
            throw new AuraHandledException('Item record is null.');
        }
        
        // Check if the current user is a manager before insertion
        if (!isCurrentUserManager()) {
            throw new AuraHandledException('Only manager users are allowed to create items.');
        }

        String imageUrl = fetchUnsplashImage(item.Name);
        item.Image__c = imageUrl;
        
        insert item;
        return item;
    }

    public static String fetchUnsplashImage(String queryTerm) {
        if (String.isBlank(queryTerm)) {
            return 'https://images.unsplash.com/photo-1531403009284-440f080d1e12?q=80&w=600';
        }
        
        try {
            String accessKey = System.Label.UnsplashAccessKey;
            // If the label is not set or contains the placeholder, return a default nice image URL
            if (String.isBlank(accessKey) || accessKey == 'PLACEHOLDER') {
                return 'https://images.unsplash.com/photo-1531403009284-440f080d1e12?q=80&w=600';
            }

            Http h = new Http();
            HttpRequest req = new HttpRequest();
            String encodedQuery = EncodingUtil.urlEncode(queryTerm, 'UTF-8');
            req.setEndpoint('https://api.unsplash.com/search/photos?query=' + encodedQuery + '&per_page=1');
            req.setMethod('GET');
            req.setHeader('Authorization', 'Client-ID ' + accessKey);
            req.setTimeout(120000);
            
            HttpResponse res = h.send(req);
            if (res.getStatusCode() == 200) {
                Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                List<Object> results = (List<Object>) body.get('results');
                if (results != null && !results.isEmpty()) {
                    Map<String, Object> firstResult = (Map<String, Object>) results[0];
                    Map<String, Object> urls = (Map<String, Object>) firstResult.get('urls');
                    if (urls != null) {
                        return (String) urls.get('regular');
                    }
                }
            }
        } catch (Exception e) {
            System.debug('Error calling Unsplash API: ' + e.getMessage());
        }
        
        return 'https://images.unsplash.com/photo-1531403009284-440f080d1e12?q=80&w=600';
    }
}
