// 1. Make current user a manager
User currentUser = [SELECT Id, IsManager__c FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
currentUser.IsManager__c = true;
update currentUser;
System.debug('Current user is now a manager: ' + currentUser.IsManager__c);

// 2. Create some dummy items
List<Item__c> items = new List<Item__c>();

items.add(new Item__c(
    Name = 'iPhone 15 Pro',
    Description__c = 'Latest Apple smartphone with Titanium design, Action button, and A17 Pro chip.',
    Type__c = 'Electronics',
    Family__c = 'Tech',
    Price__c = 999.99,
    AvailableQuantity__c = 15,
    Image__c = 'https://images.unsplash.com/photo-1510557880182-3d4d3cba35a5?q=80&w=600'
));

items.add(new Item__c(
    Name = 'Clean Code',
    Description__c = 'A handbook of agile software craftsmanship by Robert C. Martin.',
    Type__c = 'Books',
    Family__c = 'Education',
    Price__c = 39.99,
    AvailableQuantity__c = 50,
    Image__c = 'https://images.unsplash.com/photo-1544716278-ca5e3f4abd8c?q=80&w=600'
));

items.add(new Item__c(
    Name = 'Waterproof Rain Jacket',
    Description__c = 'Lightweight, windproof and waterproof jacket for outdoor activities.',
    Type__c = 'Clothing',
    Family__c = 'Apparel',
    Price__c = 79.99,
    AvailableQuantity__c = 30,
    Image__c = 'https://images.unsplash.com/photo-1548883354-7622d03aca27?q=80&w=600'
));

items.add(new Item__c(
    Name = 'Organic Green Tea',
    Description__c = 'Premium quality loose leaf organic Japanese green tea.',
    Type__c = 'Food',
    Family__c = 'Grocery',
    Price__c = 12.50,
    AvailableQuantity__c = 100,
    Image__c = 'https://images.unsplash.com/photo-1531353826977-0941b4779a1c?q=80&w=600'
));

insert items;
System.debug('Successfully inserted ' + items.size() + ' dummy items.');
