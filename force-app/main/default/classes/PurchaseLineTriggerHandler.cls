public with sharing class PurchaseLineTriggerHandler {
    public static void handle(List<PurchaseLine__c> newLines, List<PurchaseLine__c> oldLines, System.TriggerOperation opType) {
        Set<Id> purchaseIds = new Set<Id>();
        
        if (newLines != null) {
            for (PurchaseLine__c line : newLines) {
                if (line.PurchaseId__c != null) {
                    purchaseIds.add(line.PurchaseId__c);
                }
            }
        }
        if (oldLines != null) {
            for (PurchaseLine__c line : oldLines) {
                if (line.PurchaseId__c != null) {
                    purchaseIds.add(line.PurchaseId__c);
                }
            }
        }
        
        if (!purchaseIds.isEmpty()) {
            recalculatePurchases(purchaseIds);
        }
    }
    
    private static void recalculatePurchases(Set<Id> purchaseIds) {
        Map<Id, Purchase__c> purchasesToUpdate = new Map<Id, Purchase__c>();
        for (Id pId : purchaseIds) {
            purchasesToUpdate.put(pId, new Purchase__c(
                Id = pId,
                TotalItems__c = 0,
                GrandTotal__c = 0.00
            ));
        }
        
        List<PurchaseLine__c> allLines = [
            SELECT PurchaseId__c, Amount__c, UnitCost__c 
            FROM PurchaseLine__c 
            WHERE PurchaseId__c IN :purchaseIds
        ];
        
        for (PurchaseLine__c line : allLines) {
            Purchase__c parent = purchasesToUpdate.get(line.PurchaseId__c);
            Decimal qty = line.Amount__c != null ? line.Amount__c : 0;
            Decimal cost = line.UnitCost__c != null ? line.UnitCost__c : 0.00;
            
            parent.TotalItems__c += qty;
            parent.GrandTotal__c += (qty * cost);
        }
        
        if (!purchasesToUpdate.isEmpty()) {
            // Run update with user access verification to keep security tight
            Database.update(purchasesToUpdate.values(), AccessLevel.USER_MODE);
        }
    }
}
