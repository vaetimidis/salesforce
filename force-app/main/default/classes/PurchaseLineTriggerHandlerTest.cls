@isTest
public class PurchaseLineTriggerHandlerTest {

    @isTest
    static void testPurchaseCalculationTriggerLifecycle() {
        // Setup Account and Purchase parent
        Account acc = new Account(Name = 'Test Trigger Account');
        insert acc;

        Purchase__c purchase = new Purchase__c(ClientId__c = acc.Id);
        insert purchase;

        // Setup Items
        Item__c item1 = new Item__c(
            Name = 'Coffee Mug',
            Price__c = 10.00,
            AvailableQuantity__c = 50
        );
        Item__c item2 = new Item__c(
            Name = 'Notebook',
            Price__c = 5.00,
            AvailableQuantity__c = 100
        );
        insert new List<Item__c>{item1, item2};

        // 1. Test Insert
        PurchaseLine__c line1 = new PurchaseLine__c(
            PurchaseId__c = purchase.Id,
            ItemId__c = item1.Id,
            Amount__c = 3,
            UnitCost__c = 10.00
        );
        PurchaseLine__c line2 = new PurchaseLine__c(
            PurchaseId__c = purchase.Id,
            ItemId__c = item2.Id,
            Amount__c = 2,
            UnitCost__c = 5.00
        );

        Test.startTest();
        insert new List<PurchaseLine__c>{line1, line2};
        Test.stopTest();

        Purchase__c pAfterInsert = [SELECT TotalItems__c, GrandTotal__c FROM Purchase__c WHERE Id = :purchase.Id];
        // Total Items: 3 + 2 = 5
        // Grand Total: (3*10) + (2*5) = 40.00
        System.assertEquals(5, pAfterInsert.TotalItems__c, 'Total items mismatch on insert.');
        System.assertEquals(40.00, pAfterInsert.GrandTotal__c, 'Grand total mismatch on insert.');

        // 2. Test Update
        line1.Amount__c = 5; // Quantity increased from 3 to 5 (+2) -> Total 7
        line1.UnitCost__c = 12.00; // Price increased -> Grand Total: (5*12) + (2*5) = 70.00
        update line1;

        Purchase__c pAfterUpdate = [SELECT TotalItems__c, GrandTotal__c FROM Purchase__c WHERE Id = :purchase.Id];
        System.assertEquals(7, pAfterUpdate.TotalItems__c, 'Total items mismatch on update.');
        System.assertEquals(70.00, pAfterUpdate.GrandTotal__c, 'Grand total mismatch on update.');

        // 3. Test Delete
        delete line2; // Notebook line removed (qty: 2, cost: 5.00) -> Total 5, Grand Total: 60.00
        Purchase__c pAfterDelete = [SELECT TotalItems__c, GrandTotal__c FROM Purchase__c WHERE Id = :purchase.Id];
        System.assertEquals(5, pAfterDelete.TotalItems__c, 'Total items mismatch on delete.');
        System.assertEquals(60.00, pAfterDelete.GrandTotal__c, 'Grand total mismatch on delete.');

        // 4. Test Undelete
        undelete line2; // Notebook line restored -> Total 7, Grand Total: 70.00
        Purchase__c pAfterUndelete = [SELECT TotalItems__c, GrandTotal__c FROM Purchase__c WHERE Id = :purchase.Id];
        System.assertEquals(7, pAfterUndelete.TotalItems__c, 'Total items mismatch on undelete.');
        System.assertEquals(70.00, pAfterUndelete.GrandTotal__c, 'Grand total mismatch on undelete.');
    }
}
