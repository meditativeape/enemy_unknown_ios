//
//  InAppPurchaseViewController.m
//  Enemy Unknown
//
//  Created by Frank Zhang on 11/19/13.
//  Copyright (c) 2013 Comp 446. All rights reserved.
//

#import "InAppPurchaseViewController.h"
#import "EnemyUnknownAppDelegate.h"
#import "PaymentQueueObserver.h"
#import <StoreKit/SKProductsRequest.h>
#import <StoreKit/SKProduct.h>
#import <StoreKit/SKPayment.h>
#import <StoreKit/SKPaymentQueue.h>
#import <StoreKit/SKPaymentTransaction.h>

@interface InAppPurchaseViewController () <SKProductsRequestDelegate, UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) NSArray *products;
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (nonatomic, strong) SKProductsRequest *request;
@property (nonatomic, strong) UIImage *purchaseImage;

@end

@implementation InAppPurchaseViewController

- (void) viewDidLoad
{
    // register observer
    EnemyUnknownAppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
    PaymentQueueObserver *pqObserver = appDelegate.pqObserver;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(transactionStateChanged:)
                                                 name:nil
                                               object:pqObserver];
    
    // fetch product info
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"product_ids" withExtension:@"plist"];
    NSArray *productIds = [NSArray arrayWithContentsOfURL:url];
    [self validateProductIds:productIds];
}

- (void)validateProductIds:(NSArray *)productIds
{
    self.request = [[SKProductsRequest alloc]
                    initWithProductIdentifiers:[NSSet setWithArray:productIds]];
    self.request.delegate = self;
    [self.request start];
}

- (void) displayStoreUI
{
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.rowHeight = 100;
    
    NSString *filepath = [[NSBundle mainBundle] pathForResource:@"purchase" ofType:@"png"];
    NSURL *fileURL = [NSURL fileURLWithPath:filepath];
    NSData *fileData = [NSData dataWithContentsOfURL:fileURL];
    self.purchaseImage = [UIImage imageWithData:fileData];
    
    [self.tableView reloadData];
    self.tableView.hidden = NO;
}

- (void)checkButtonTapped:(id)sender event:(id)event
{
    NSSet *touches = [event allTouches];
    UITouch *touch = [touches anyObject];
    CGPoint currentTouchPos = [touch locationInView:self.tableView];
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:currentTouchPos];
    if (indexPath != nil) {
        [self buyProduct:[indexPath row]];
    }
}

- (void)transactionStateChanged:(NSNotification *)notification
{
    // find the row index product related to this transaction
    SKPaymentTransaction *transaction = notification.userInfo[@"transaction"];
    NSString *productId = transaction.payment.productIdentifier;
    NSInteger index = 0;
    for (; index < [self.products count]; index++) {
        if (((SKProduct *)self.products[index]).productIdentifier == productId)
            break;
    }
    
    // find the button in that row
    UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:index inSection:0]];
    // cell not visible, so do nothing
    if (cell == nil)
        return;
    UIButton *button = (UIButton *)cell.accessoryView;
    
    // modify the button
    if ([notification.name isEqualToString:transactionOngoingNotification]) {
        [button setTitle:@"Processing..." forState:UIControlStateNormal];
        [button removeTarget:self
                      action:@selector(checkButtonTapped:event:)
            forControlEvents:UIControlEventTouchUpInside];
         
    } else if ([notification.name isEqualToString:transactionSucceededNotification]) {
        [button setTitle:@"Bought" forState:UIControlStateNormal];
        [button removeTarget:self
                      action:@selector(checkButtonTapped:event:)
            forControlEvents:UIControlEventTouchUpInside];
        
    } else if ([notification.name isEqualToString:transactionFailedNotification]) {
        [button setTitle:[NSString stringWithFormat:@"Buy at $%@", ((SKProduct *)self.products[index]).price]
                   forState:UIControlStateNormal];
        [button addTarget:self
                      action:@selector(checkButtonTapped:event:)
            forControlEvents:UIControlEventTouchUpInside];
    }
}

- (void)buyProduct:(NSInteger)row
{
    SKProduct *product = self.products[row];
    SKMutablePayment *payment = [SKMutablePayment paymentWithProduct:product];
    payment.quantity = 1;
    [[SKPaymentQueue defaultQueue] addPayment:payment];
}

- (IBAction) back:(UIButton *)sender
{
    [self.navigationController popViewControllerAnimated:YES];
}

#pragma mark - SKProductsRequest delegate

- (void) productsRequest:(SKProductsRequest *)request
     didReceiveResponse:(SKProductsResponse *)response
{
    self.products = response.products;
    
    for (NSString *invalidId in response.invalidProductIdentifiers) {
        // handle invalid id
    }
    
    [self displayStoreUI];
}

- (void) request:(SKRequest *)request
didFailWithError:(NSError *)error
{
    NSLog(@"SKRequest failed: %@", error.localizedDescription);
}

#pragma mark - Table view data source

- (NSInteger) tableView:(UITableView *)tableView
  numberOfRowsInSection:(NSInteger)section
{
    return [self.products count];
}

- (UITableViewCell *) tableView:(UITableView *)tableView
          cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *cellIdentifier = @"Item For Purchase";
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:cellIdentifier
                                                                 forIndexPath:indexPath];
    NSInteger row = [indexPath row];
    
    // configure cell
    cell.textLabel.text = ((SKProduct *)self.products[row]).localizedTitle;
    cell.textLabel.textColor = [UIColor whiteColor];
    cell.detailTextLabel.text = ((SKProduct *)self.products[row]).localizedDescription;
    cell.detailTextLabel.textColor = [UIColor whiteColor];
    
    UIButton *buyButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    NSUserDefaults *storage = [NSUserDefaults standardUserDefaults];
    BOOL bought = [storage boolForKey:((SKProduct *)self.products[row]).productIdentifier];
    if (!bought) {
        [buyButton setTitle:[NSString stringWithFormat:@"Buy at $%@",
                             ((SKProduct *)self.products[row]).price]
                   forState:UIControlStateNormal];
        [buyButton addTarget:self
                      action:@selector(checkButtonTapped:event:)
            forControlEvents:UIControlEventTouchUpInside];
    } else {
        [buyButton setTitle:@"Bought"
                   forState:UIControlStateNormal];
    }
    [buyButton setFrame:CGRectMake(0, 0, 100, 35)];
    cell.accessoryView = buyButton;
    
    cell.imageView.image = self.purchaseImage;
    
    return cell;
}

#pragma mark - Table view delegate

// Does not allow any cell to be selected
- (NSIndexPath *)tableView:(UITableView *)tableView
  willSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    return nil;
}

// Change background color
- (void)tableView:(UITableView *)tableView
  willDisplayCell:(UITableViewCell *)cell
forRowAtIndexPath:(NSIndexPath *)indexPath
{
    [cell setBackgroundColor:[UIColor blackColor]];
}

@end
