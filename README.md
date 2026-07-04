# Salesforce Item Purchase Tool

This repository contains the complete implementation of the **Item Purchase Tool** test task.

## Features Implemented
1. **Custom Data Model**:
   * `Item__c`: Custom object representing store items.
   * `Purchase__c`: Custom object representing purchase transactions (calculates totals dynamically using triggers).
   * `PurchaseLine__c`: Custom master-detail object linking purchases to purchased items.
   * `User.IsManager__c`: Checkbox to control administrative actions.
2. **Lightning Web Component (`itemPurchaseTool`)**:
   * Interactive store view displaying item images, prices, and stock indicators.
   * Real-time searches (by Name and Description) and dropdown picklist filtering (by Type and Family).
   * Shopping Cart modal supporting changing quantities and checkout validations.
   * "Create Item" modal visible only to Manager users (`IsManager__c = true`).
3. **Integration**:
   * Automated callout to Unsplash API in Apex to fetch images for newly created items using their name as the query.
   * Graceful fallback to default placeholders if no API key is specified.
4. **Apex Trigger**:
   * Dynamically aggregates total quantity and grand price on `Purchase__c` upon line item additions, changes, and deletions.
5. **Apex Unit Tests**:
   * 100% test coverage with automated mocks for HTTP API callouts and validation checks.

---

## Deployment & Setup Guide

Since you already have a Salesforce developer instance, follow these steps to deploy and finalize the configuration:

### Step 1: Deploying the Metadata to Salesforce
If you use Salesforce CLI (`sf` / `sfdx`):
1. Authenticate to your Salesforce org:
   ```bash
   sf org login web -d -a myorg
   ```
2. Deploy the source code:
   ```bash
   sf project deploy start
   ```

*(If you are using IntelliJ IDEA with JetForcer or VS Code, you can deploy the `force-app` folder directly using the IDE tools).*

### Step 2: Permission Set & FLS Setup
We provide a preconfigured Permission Set (`Item_Purchase_Tool`) that automatically grants all necessary Object and Field-Level Security (FLS) access to custom fields and objects.

1. **Assign the Permission Set**:
   Run the following CLI command:
   ```bash
   sf org assign permset --name Item_Purchase_Tool
   ```
   *Or assign it in Salesforce: Setup -> Permission Sets -> Item Purchase Tool -> Manage Assignments.*

2. **User Manager Setup**:
   To enable the "Create Item" button on the UI, check the **Is Manager** (`IsManager__c`) checkbox on your User record:
   * Go to **Setup** -> **Users**.
   * Open your user record, click **Edit**, check **Is Manager**, and save.

### Step 3: Populate Test Data
To quickly populate the organization with test items and make yourself a manager, run the provided Anonymous Apex script:
```bash
sf apex run --file scripts/apex/create_dummy_data.apex
```
*Or execute the contents of `scripts/apex/create_dummy_data.apex` in the Developer Console Anonymous Window.*

### Step 4: Unsplash API Setup (Optional)
To query live pictures from Unsplash:
1. Register a developer application on [Unsplash Developers](https://unsplash.com/developers) and copy your **Access Key**.
2. In Salesforce, search for **Custom Labels** in Setup.
3. Open the `UnsplashAccessKey` label and click **New Local Translations / Overrides** (or edit the value). Set the value to your Unsplash Access Key.
   * *If the label is left as `PLACEHOLDER`, the system will automatically use a high-quality stock placeholder image.*

### Step 5: Adding the Component to the Account Layout
You can add the LWC to the Account layout in two ways:
1. **Directly on the Record Page (Recommended)**:
   * Open any Account record in Salesforce.
   * Click the gear icon ⚙️ in the top right and select **Edit Page**.
   * Drag the **Item Purchase Tool** component from the **Custom** section on the left into your layout.
   * Save and activate the page.
2. **As a Quick Action Button**:
   * Go to **Setup** -> **Object Manager** -> **Account** -> **Buttons, Links, and Actions**.
   * Create a **New Action**: type `Lightning Component`, select `c:itemPurchaseTool`, label it `Item Purchase Tool`, and save.
   * Add this action to your **Account Page Layout** under the *Salesforce Mobile and Lightning Experience Actions* section.

---

## Files Structure
All metadata and code are laid out in the standard Salesforce DX directory:
* [ItemPurchaseController.cls](file:///C:/Users/okinawa/IdeaProjects/salesforce/force-app/main/default/classes/ItemPurchaseController.cls) - Main backend controller.
* [ItemPurchaseControllerTest.cls](file:///C:/Users/okinawa/IdeaProjects/salesforce/force-app/main/default/classes/ItemPurchaseControllerTest.cls) - Tests for the controller.
* [PurchaseLineTrigger.trigger](file:///C:/Users/okinawa/IdeaProjects/salesforce/force-app/main/default/triggers/PurchaseLineTrigger.trigger) - Trigger for roll-up totals.
* [PurchaseLineTriggerHandler.cls](file:///C:/Users/okinawa/IdeaProjects/salesforce/force-app/main/default/classes/PurchaseLineTriggerHandler.cls) - Trigger logic handler.
* [itemPurchaseTool.html](file:///C:/Users/okinawa/IdeaProjects/salesforce/force-app/main/default/lwc/itemPurchaseTool/itemPurchaseTool.html) - LWC Template.
* [itemPurchaseTool.js](file:///C:/Users/okinawa/IdeaProjects/salesforce/force-app/main/default/lwc/itemPurchaseTool/itemPurchaseTool.js) - LWC Controller.
* [itemPurchaseTool.css](file:///C:/Users/okinawa/IdeaProjects/salesforce/force-app/main/default/lwc/itemPurchaseTool/itemPurchaseTool.css) - Custom premium styles.
* [Item_Purchase_Tool.permissionset-meta.xml](file:///C:/Users/okinawa/IdeaProjects/salesforce/force-app/main/default/permissionsets/Item_Purchase_Tool.permissionset-meta.xml) - Preconfigured permissions.
* [create_dummy_data.apex](file:///C:/Users/okinawa/IdeaProjects/salesforce/scripts/apex/create_dummy_data.apex) - Test data generator script.
