import { LightningElement, api, track, wire } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

// Apex controllers
import getAccountDetails from '@salesforce/apex/ItemPurchaseController.getAccountDetails';
import getItems from '@salesforce/apex/ItemPurchaseController.getItems';
import isCurrentUserManager from '@salesforce/apex/ItemPurchaseController.isCurrentUserManager';
import checkoutCart from '@salesforce/apex/ItemPurchaseController.checkoutCart';
import createNewItem from '@salesforce/apex/ItemPurchaseController.createNewItem';

export default class ItemPurchaseTool extends NavigationMixin(LightningElement) {
    _recordId;

    @api
    get recordId() {
        console.log('LWC: get recordId =', this._recordId);
        return this._recordId;
    }
    set recordId(value) {
        console.log('LWC: set recordId =', value);
        const oldValue = this._recordId;
        this._recordId = value;
        if (value && value !== oldValue) {
            console.log('LWC: recordId changed, calling loadAccountInfo()');
            this.loadAccountInfo();
        }
    }

    @track account;
    @track items = [];
    @track cart = [];
    
    // Filters state
    searchKey = '';
    selectedType = '';
    selectedFamily = '';
    
    // UI state
    isLoading = false;
    isManager = false;
    
    // Modals state
    isDetailsModalOpen = false;
    isCartModalOpen = false;
    isCreateModalOpen = false;
    
    // Selected item for detail view
    selectedItem = {};

    @track newItem = {
        Name: '',
        Description__c: '',
        Type__c: '',
        Family__c: '',
        Price__c: 0,
        AvailableQuantity__c: 0
    };

    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference && !this.recordId) {
            const state = currentPageReference.state;
            if (state && state.c__recordId) {
                this.recordId = state.c__recordId;
                this.loadAccountInfo();
            }
        }
    }

    typeOptions = [
        { label: 'All Types', value: '' },
        { label: 'Electronics', value: 'Electronics' },
        { label: 'Books', value: 'Books' },
        { label: 'Clothing', value: 'Clothing' },
        { label: 'Food', value: 'Food' },
        { label: 'Other', value: 'Other' }
    ];

    familyOptions = [
        { label: 'All Families', value: '' },
        { label: 'Tech', value: 'Tech' },
        { label: 'Education', value: 'Education' },
        { label: 'Apparel', value: 'Apparel' },
        { label: 'Grocery', value: 'Grocery' },
        { label: 'General', value: 'General' }
    ];

    get typeOptionsWithoutAll() {
        return this.typeOptions.filter(opt => opt.value !== '');
    }

    get familyOptionsWithoutAll() {
        return this.familyOptions.filter(opt => opt.value !== '');
    }

    connectedCallback() {
        console.log('LWC: connectedCallback, initial recordId =', this.recordId);
        this.loadAccountInfo();
        this.checkManagerStatus();
        this.loadItems();
    }

    loadAccountInfo() {
        console.log('LWC: loadAccountInfo, recordId =', this.recordId);
        if (this.recordId) {
            getAccountDetails({ accountId: this.recordId })
                .then(result => {
                    console.log('LWC: getAccountDetails success, result =', result);
                    this.account = result;
                })
                .catch(error => {
                    console.error('LWC: getAccountDetails error =', error);
                    this.showToast('Error', 'Failed to retrieve Account details: ' + (error.body ? error.body.message : error.message), 'error');
                });
        } else {
            console.warn('LWC: loadAccountInfo skipped because recordId is falsy');
        }
    }

    // Verify if running user has manager status
    checkManagerStatus() {
        isCurrentUserManager()
            .then(result => {
                this.isManager = result;
            })
            .catch(error => {
                console.error('Error checking manager privileges:', error);
            });
    }

    // Load items based on filters
    loadItems() {
        this.isLoading = true;
        getItems({
            searchKey: this.searchKey,
            familyFilter: this.selectedFamily,
            typeFilter: this.selectedType
        })
        .then(result => {
            this.items = result.map(item => {
                const isOutOfStock = !item.AvailableQuantity__c || item.AvailableQuantity__c <= 0;
                
                // Track remaining quantity considering items in the cart
                const cartItem = this.cart.find(c => c.itemId === item.Id);
                const cartQty = cartItem ? cartItem.quantity : 0;
                const effectiveStock = item.AvailableQuantity__c - cartQty;

                return {
                    ...item,
                    isOutOfStock: isOutOfStock || effectiveStock <= 0,
                    stockClass: isOutOfStock || effectiveStock <= 0 ? 'stock-badge out-of-stock' : 'stock-badge in-stock'
                };
            });
        })
        .catch(error => {
            this.showToast('Error', 'Failed to load items: ' + (error.body ? error.body.message : error.message), 'error');
        })
        .finally(() => {
            this.isLoading = false;
        });
    }

    // Filters event handlers
    handleSearchChange(event) {
        this.searchKey = event.target.value;
        // Debounce search
        clearTimeout(this.searchTimer);
        this.searchTimer = setTimeout(() => {
            this.loadItems();
        }, 300);
    }

    handleTypeChange(event) {
        this.selectedType = event.target.value;
        this.loadItems();
    }

    handleFamilyChange(event) {
        this.selectedFamily = event.target.value;
        this.loadItems();
    }

    // Computations
    get itemsCount() {
        return this.items.length;
    }

    get hasItems() {
        return this.items.length > 0;
    }

    get cartItemsCount() {
        return this.cart.reduce((total, item) => total + item.quantity, 0);
    }

    get cartButtonLabel() {
        const count = this.cartItemsCount;
        return count > 0 ? `Cart (${count})` : 'Cart';
    }

    get isCartEmpty() {
        return this.cart.length === 0;
    }

    get cartGrandTotal() {
        return this.cart.reduce((total, item) => total + (item.unitPrice * item.quantity), 0).toFixed(2);
    }

    // Cart Management
    handleAddToCart(event) {
        const itemId = event.target.dataset.id;
        const item = this.items.find(i => i.Id === itemId);

        if (!item || item.AvailableQuantity__c <= 0) {
            this.showToast('Out of Stock', 'This item is currently out of stock.', 'warning');
            return;
        }

        const existingCartItem = this.cart.find(c => c.itemId === itemId);
        const currentQtyInCart = existingCartItem ? existingCartItem.quantity : 0;

        if (currentQtyInCart >= item.AvailableQuantity__c) {
            this.showToast('Out of Stock', 'Cannot add more. You have selected all available stock.', 'warning');
            return;
        }

        if (existingCartItem) {
            existingCartItem.quantity += 1;
            existingCartItem.totalCost = (existingCartItem.quantity * existingCartItem.unitPrice).toFixed(2);
            this.cart = [...this.cart];
        } else {
            this.cart = [...this.cart, {
                itemId: item.Id,
                name: item.Name,
                image: item.Image__c,
                unitPrice: item.Price__c,
                quantity: 1,
                totalCost: item.Price__c.toFixed(2)
            }];
        }

        this.showToast('Success', `${item.Name} added to cart.`, 'success');
        this.loadItems(); // Refresh inventory badges
    }

    decreaseCartItemQuantity(event) {
        const itemId = event.target.dataset.id;
        const cartItemIndex = this.cart.findIndex(c => c.itemId === itemId);

        if (cartItemIndex !== -1) {
            const item = this.cart[cartItemIndex];
            if (item.quantity > 1) {
                item.quantity -= 1;
                item.totalCost = (item.quantity * item.unitPrice).toFixed(2);
                this.cart = [...this.cart];
            } else {
                // Remove item if quantity goes to 0
                this.cart.splice(cartItemIndex, 1);
                this.cart = [...this.cart];
            }
            this.loadItems();
        }
    }

    increaseCartItemQuantity(event) {
        const itemId = event.target.dataset.id;
        const dbItem = this.items.find(i => i.Id === itemId);
        const cartItem = this.cart.find(c => c.itemId === itemId);

        if (cartItem && dbItem) {
            if (cartItem.quantity >= dbItem.AvailableQuantity__c) {
                this.showToast('Out of Stock', 'Cannot add more. Exceeds available stock.', 'warning');
                return;
            }
            cartItem.quantity += 1;
            cartItem.totalCost = (cartItem.quantity * cartItem.unitPrice).toFixed(2);
            this.cart = [...this.cart];
            this.loadItems();
        }
    }

    removeCartItem(event) {
        const itemId = event.target.dataset.id;
        this.cart = this.cart.filter(c => c.itemId !== itemId);
        this.loadItems();
    }

    // Modal Control Handlers
    openDetailsModal(event) {
        const itemId = event.target.dataset.id;
        this.selectedItem = this.items.find(i => i.Id === itemId);
        this.isDetailsModalOpen = true;
    }

    closeDetailsModal() {
        this.isDetailsModalOpen = false;
        this.selectedItem = {};
    }

    openCartModal() {
        this.isCartModalOpen = true;
    }

    closeCartModal() {
        this.isCartModalOpen = false;
    }

    openCreateModal() {
        this.isCreateModalOpen = true;
        this.newItem = {
            Name: '',
            Description__c: '',
            Type__c: '',
            Family__c: '',
            Price__c: 0,
            AvailableQuantity__c: 0
        };
    }

    closeCreateModal() {
        this.isCreateModalOpen = false;
    }

    // Create New Item logic
    handleNewItemChange(event) {
        const fieldName = event.target.dataset.field;
        const fieldValue = event.target.value;
        this.newItem = {
            ...this.newItem,
            [fieldName]: fieldValue
        };
    }

    handleSaveItem() {
        // Simple validations
        if (!this.newItem.Name || !this.newItem.Price__c || !this.newItem.Type__c || !this.newItem.Family__c) {
            this.showToast('Required Fields', 'Please complete all required fields.', 'error');
            return;
        }

        this.isLoading = true;
        this.isCreateModalOpen = false;

        createNewItem({ item: this.newItem })
            .then(result => {
                this.showToast('Success', `Item "${result.Name}" successfully created. Image will be fetched from Unsplash.`, 'success');
                this.loadItems();
            })
            .catch(error => {
                this.showToast('Error Creating Item', error.body ? error.body.message : error.message, 'error');
                this.isCreateModalOpen = true; // reopen modal on error
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    // Checkout execution
    handleCheckout() {
        if (!this.recordId) {
            this.showToast('Error', 'Account context not found. Cannot checkout.', 'error');
            return;
        }

        this.isLoading = true;
        this.isCartModalOpen = false;

        // Strip UI information and send only required params
        const cartDto = this.cart.map(c => ({
            itemId: c.itemId,
            quantity: c.quantity,
            unitPrice: parseFloat(c.unitPrice)
        }));

        checkoutCart({
            accountId: this.recordId,
            cartItemsJson: JSON.stringify(cartDto)
        })
        .then(purchaseId => {
            this.showToast('Checkout Complete', 'Purchase order successfully created.', 'success');
            this.cart = []; // clear cart
            
            // Redirect to standard Purchase detail page
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: purchaseId,
                    objectApiName: 'Purchase__c',
                    actionName: 'view'
                }
            });
        })
        .catch(error => {
            this.showToast('Checkout Failed', error.body ? error.body.message : error.message, 'error');
            this.isCartModalOpen = true; // reopen modal on error
        })
        .finally(() => {
            this.isLoading = false;
        });
    }

    // Standard toast notification helper
    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant
            })
        );
    }
}
