trigger PurchaseLineTrigger on PurchaseLine__c (after insert, after update, after delete, after undelete) {
    PurchaseLineTriggerHandler.handle(Trigger.new, Trigger.old, Trigger.operationType);
}
