@isTest
public class ItemPurchaseControllerTest {

    // Inner class mock to simulate Unsplash API response
    public class UnsplashCalloutMock implements HttpCalloutMock {
        private Boolean triggerError;
        public UnsplashCalloutMock(Boolean triggerError) {
            this.triggerError = triggerError;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            if (triggerError) {
                res.setStatusCode(400);
                res.setBody('{"errors": ["Bad Request"]}');
            } else {
                res.setStatusCode(200);
                res.setBody('{' +
                    '"results": [' +
                        '{' +
                            '"urls": {' +
                                '"regular": "https://images.unsplash.com/mock-regular-image-url.jpg"' +
                            '}' +
                        '}' +
                    ']' +
                '}');
            }
            return res;
        }
    }

    @TestSetup
    static void setupTestData() {
        // Create a test account
        Account acc = new Account(
            Name = 'Test Corporate Account',
            AccountNumber = 'ACC-12345',
            Industry = 'Technology'
        );
        insert acc;

        // Create test items
        List<Item__c> testItems = new List<Item__c>{
            new Item__c(
                Name = 'Premium Laptop',
                Description__c = 'High-end developer laptop with 32GB RAM.',
                Type__c = 'Electronics',
                Family__c = 'Tech',
                Price__c = 1500.00,
                AvailableQuantity__c = 10
            ),
            new Item__c(
                Name = 'Apex Programming Guide',
                Description__c = 'Complete reference manual for Salesforce Apex development.',
                Type__c = 'Books',
                Family__c = 'Education',
                Price__c = 50.00,
                AvailableQuantity__c = 5
            ),
            new Item__c(
                Name = 'Out of Stock Item',
                Description__c = 'An item with zero inventory.',
                Type__c = 'Other',
                Family__c = 'General',
                Price__c = 10.00,
                AvailableQuantity__c = 0
            )
        };
        insert testItems;
    }

    @isTest
    static void testGetAccountDetailsSuccess() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        
        Test.startTest();
        Account result = ItemPurchaseController.getAccountDetails(acc.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Account should be found.');
        System.assertEquals('Test Corporate Account', result.Name, 'Account name mismatch.');
        System.assertEquals('ACC-12345', result.AccountNumber, 'Account number mismatch.');
    }

    @isTest
    static void testGetAccountDetailsNullThrowsException() {
        Test.startTest();
        try {
            ItemPurchaseController.getAccountDetails(null);
            System.assert(false, 'Exception should have been thrown.');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('Account ID cannot be null'), 'Expected error message not found.');
        }
        Test.stopTest();
    }

    @isTest
    static void testGetItemsFilters() {
        Test.startTest();
        // 1. Get all items
        List<Item__c> allItems = ItemPurchaseController.getItems('', '', '');
        System.assertEquals(3, allItems.size(), 'Should return all 3 items.');

        // 2. Filter by search key
        List<Item__c> searchItems = ItemPurchaseController.getItems('laptop', '', '');
        System.assertEquals(1, searchItems.size(), 'Should return 1 item matching search key.');
        System.assertEquals('Premium Laptop', searchItems[0].Name, 'Should match name.');

        // 3. Filter by type
        List<Item__c> typeItems = ItemPurchaseController.getItems('', '', 'Books');
        System.assertEquals(1, typeItems.size(), 'Should return 1 item matching type.');

        // 4. Filter by family
        List<Item__c> familyItems = ItemPurchaseController.getItems('', 'Tech', '');
        System.assertEquals(1, familyItems.size(), 'Should return 1 item matching family.');
        Test.stopTest();
    }

    @isTest
    static void testIsCurrentUserManager() {
        // Query a standard user profile to create a test user
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User' LIMIT 1];
        
        // 1. Test with IsManager = true
        User mgrUser = new User(
            Alias = 'mgrusr',
            Email = 'manager@truesolv.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'ManagerUser',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'manager' + DateTime.now().getTime() + '@truesolv.com',
            IsManager__c = true
        );
        insert mgrUser;

        System.runAs(mgrUser) {
            System.assertEquals(true, ItemPurchaseController.isCurrentUserManager(), 'Should return true for manager user.');
        }

        // 2. Test with IsManager = false
        User regularUser = new User(
            Alias = 'regusr',
            Email = 'regular@truesolv.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'RegularUser',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'regular' + DateTime.now().getTime() + '@truesolv.com',
            IsManager__c = false
        );
        insert regularUser;

        System.runAs(regularUser) {
            System.assertEquals(false, ItemPurchaseController.isCurrentUserManager(), 'Should return false for non-manager user.');
        }
    }

    @isTest
    static void testCheckoutCartSuccess() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Item__c laptop = [SELECT Id, Price__c, AvailableQuantity__c FROM Item__c WHERE Name = 'Premium Laptop' LIMIT 1];
        Item__c book = [SELECT Id, Price__c, AvailableQuantity__c FROM Item__c WHERE Name = 'Apex Programming Guide' LIMIT 1];

        // Construct JSON representation of cart items
        List<ItemPurchaseController.CartItem> cartList = new List<ItemPurchaseController.CartItem>();
        
        ItemPurchaseController.CartItem ci1 = new ItemPurchaseController.CartItem();
        ci1.itemId = laptop.Id;
        ci1.quantity = 2;
        ci1.unitPrice = laptop.Price__c;
        cartList.add(ci1);

        ItemPurchaseController.CartItem ci2 = new ItemPurchaseController.CartItem();
        ci2.itemId = book.Id;
        ci2.quantity = 1;
        ci2.unitPrice = book.Price__c;
        cartList.add(ci2);

        String cartJson = JSON.serialize(cartList);

        Test.startTest();
        Id purchaseId = ItemPurchaseController.checkoutCart(acc.Id, cartJson);
        Test.stopTest();

        System.assertNotEquals(null, purchaseId, 'Purchase ID should be returned.');
        
        // Assert records were created
        Purchase__c purchase = [SELECT Id, TotalItems__c, GrandTotal__c FROM Purchase__c WHERE Id = :purchaseId];
        System.assertEquals(3, purchase.TotalItems__c, 'Total items calculation failed.');
        System.assertEquals(3050.00, purchase.GrandTotal__c, 'Grand total calculation failed.');

        List<PurchaseLine__c> lines = [SELECT Id, Amount__c, UnitCost__c FROM PurchaseLine__c WHERE PurchaseId__c = :purchaseId];
        System.assertEquals(2, lines.size(), 'Should have created exactly 2 purchase lines.');

        // Assert quantities were decremented
        Item__c updatedLaptop = [SELECT AvailableQuantity__c FROM Item__c WHERE Id = :laptop.Id];
        System.assertEquals(8, updatedLaptop.AvailableQuantity__c, 'Laptop stock was not decremented correctly.');
        Item__c updatedBook = [SELECT AvailableQuantity__c FROM Item__c WHERE Id = :book.Id];
        System.assertEquals(4, updatedBook.AvailableQuantity__c, 'Book stock was not decremented correctly.');
    }

    @isTest
    static void testCheckoutCartInsufficientStockThrowsException() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Item__c laptop = [SELECT Id, Price__c FROM Item__c WHERE Name = 'Premium Laptop' LIMIT 1];

        List<ItemPurchaseController.CartItem> cartList = new List<ItemPurchaseController.CartItem>();
        ItemPurchaseController.CartItem ci = new ItemPurchaseController.CartItem();
        ci.itemId = laptop.Id;
        ci.quantity = 15; // Exceeds available stock of 10
        ci.unitPrice = laptop.Price__c;
        cartList.add(ci);

        String cartJson = JSON.serialize(cartList);

        Test.startTest();
        try {
            ItemPurchaseController.checkoutCart(acc.Id, cartJson);
            System.assert(false, 'Should have thrown stock exception.');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('Insufficient stock'), 'Expected stock error message not thrown.');
        }
        Test.stopTest();
    }

    @isTest
    static void testCreateNewItemAsManagerSuccess() {
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User' LIMIT 1];
        User mgrUser = new User(
            Alias = 'mgrusr',
            Email = 'manager@truesolv.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'ManagerUser',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'manager' + DateTime.now().getTime() + '@truesolv.com',
            IsManager__c = true
        );
        insert mgrUser;

        System.runAs(mgrUser) {
            Item__c newItem = new Item__c(
                Name = 'Designer Coffee Mug',
                Description__c = 'A beautiful mug for developers.',
                Type__c = 'Other',
                Family__c = 'General',
                Price__c = 15.00,
                AvailableQuantity__c = 100
            );

            // Set the HTTP Callout Mock
            Test.setMock(HttpCalloutMock.class, new UnsplashCalloutMock(false));

            Test.startTest();
            Item__c result = ItemPurchaseController.createNewItem(newItem);
            Test.stopTest();

            System.assertNotEquals(null, result.Id, 'New item should be saved.');
            System.assertEquals('https://images.unsplash.com/mock-regular-image-url.jpg', result.Image__c, 'Should use Unsplash mock image.');
        }
    }

    @isTest
    static void testCreateNewItemAsNonManagerThrowsException() {
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User' LIMIT 1];
        User regularUser = new User(
            Alias = 'regusr',
            Email = 'regular@truesolv.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'RegularUser',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'regular' + DateTime.now().getTime() + '@truesolv.com',
            IsManager__c = false
        );
        insert regularUser;

        System.runAs(regularUser) {
            Item__c newItem = new Item__c(
                Name = 'Unauthorized Item',
                Description__c = 'Should fail insertion.',
                Price__c = 5.00,
                AvailableQuantity__c = 10
            );

            Test.startTest();
            try {
                ItemPurchaseController.createNewItem(newItem);
                System.assert(false, 'Should have thrown authentication exception.');
            } catch (Exception e) {
                System.assert(e.getMessage().contains('Only manager users are allowed'), 'Expected manager check error not thrown.');
            }
            Test.stopTest();
        }
    }

    @isTest
    static void testFetchUnsplashImageCalloutErrorFallback() {
        // Set the HTTP Callout Mock to return an error response (e.g. 400 Bad Request)
        Test.setMock(HttpCalloutMock.class, new UnsplashCalloutMock(true));

        Test.startTest();
        String result = ItemPurchaseController.fetchUnsplashImage('Apple');
        Test.stopTest();

        // Should return the default fallback URL upon error
        System.assert(result.startsWith('https://images.unsplash.com/photo-1531403009284-440f080d1e12'), 'Should fall back to default placeholder URL on API error.');
    }
}
