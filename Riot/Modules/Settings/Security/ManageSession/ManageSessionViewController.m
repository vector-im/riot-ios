/*
 Copyright 2020 New Vector Ltd
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

#import "ManageSessionViewController.h"

#import <MatrixKit/MatrixKit.h>

#import <OLMKit/OLMKit.h>

#import "AppDelegate.h"
#import "AvatarGenerator.h"

#import "ThemeService.h"

#import "Riot-Swift.h"


enum
{
    SECTION_SESSION_INFO,
    SECTION_ACTION,
    SECTION_COUNT
};

enum {
    SESSION_INFO_SESSION_NAME,
    SESSION_INFO_TRUST,
    SESSION_INFO_COUNT
};

enum {
    ACTION_REMOVE_SESSION,
    ACTION_COUNT
};


@interface ManageSessionViewController ()
{
    // The device to display
    MXDevice *device;
    
    // Current alert (if any).
    UIAlertController *currentAlert;
    
    // Observe kThemeServiceDidChangeThemeNotification to handle user interface theme change.
    id kThemeServiceDidChangeThemeNotificationObserver;

    // The current pushed view controller
    UIViewController *pushedViewController;
}

@property (nonatomic, strong) UserVerificationCoordinatorBridgePresenter *userVerificationCoordinatorBridgePresenter;

@end

@implementation ManageSessionViewController

#pragma mark - Setup & Teardown

+ (ManageSessionViewController*)instantiateWithMatrixSession:(MXSession*)matrixSession andDevice:(MXDevice*)device;
{
    ManageSessionViewController* viewController = [[UIStoryboard storyboardWithName:@"ManageSession" bundle:[NSBundle mainBundle]] instantiateInitialViewController];
    [viewController addMatrixSession:matrixSession];
    viewController->device = device;
    return viewController;
}


#pragma mark - View life cycle

- (void)finalizeInit
{
    [super finalizeInit];
    
    // Setup `MXKViewControllerHandling` properties
    self.enableBarTintColorStatusChange = NO;
    self.rageShakeManager = [RageShakeManager sharedManager];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    self.navigationItem.title = NSLocalizedStringFromTable(@"manage_session_title", @"Vector", nil);
    
    // Remove back bar button title when pushing a view controller
    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"" style:UIBarButtonItemStylePlain target:nil action:nil];

    [self.tableView registerClass:MXKTableViewCellWithLabelAndTextField.class forCellReuseIdentifier:[MXKTableViewCellWithLabelAndTextField defaultReuseIdentifier]];
    [self.tableView registerClass:MXKTableViewCellWithLabelAndSwitch.class forCellReuseIdentifier:[MXKTableViewCellWithLabelAndSwitch defaultReuseIdentifier]];
    [self.tableView registerNib:MXKTableViewCellWithTextView.nib forCellReuseIdentifier:[MXKTableViewCellWithTextView defaultReuseIdentifier]];
    
    // Enable self sizing cells
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 50;

    // Observe user interface theme change.
    kThemeServiceDidChangeThemeNotificationObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kThemeServiceDidChangeThemeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {
        
        [self userInterfaceThemeDidChange];
        
    }];
    [self userInterfaceThemeDidChange];
}

- (void)userInterfaceThemeDidChange
{
    [ThemeService.shared.theme applyStyleOnNavigationBar:self.navigationController.navigationBar];

    self.activityIndicator.backgroundColor = ThemeService.shared.theme.overlayBackgroundColor;
    
    // Check the table view style to select its bg color.
    self.tableView.backgroundColor = ((self.tableView.style == UITableViewStylePlain) ? ThemeService.shared.theme.backgroundColor : ThemeService.shared.theme.headerBackgroundColor);
    self.view.backgroundColor = self.tableView.backgroundColor;
    self.tableView.separatorColor = ThemeService.shared.theme.lineBreakColor;
    
    [self reloadData];

    [self setNeedsStatusBarAppearanceUpdate];
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return ThemeService.shared.theme.statusBarStyle;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)destroy
{
    // Release the potential pushed view controller
    [self releasePushedViewController];
    
    if (kThemeServiceDidChangeThemeNotificationObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:kThemeServiceDidChangeThemeNotificationObserver];
        kThemeServiceDidChangeThemeNotificationObserver = nil;
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    // Screen tracking
    [[Analytics sharedInstance] trackScreen:@"ManageSession"];

    // Release the potential pushed view controller
    [self releasePushedViewController];

    // Refresh display
    [self reloadData];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];

    if (currentAlert)
    {
        [currentAlert dismissViewControllerAnimated:NO completion:nil];
        currentAlert = nil;
    }
}

#pragma mark - Internal methods

- (void)pushViewController:(UIViewController*)viewController
{
    // Keep ref on pushed view controller
    pushedViewController = viewController;

    // Hide back button title
    self.navigationItem.backBarButtonItem =[[UIBarButtonItem alloc] initWithTitle:@"" style:UIBarButtonItemStylePlain target:nil action:nil];

    [self.navigationController pushViewController:viewController animated:YES];
}

- (void)releasePushedViewController
{
    if (pushedViewController)
    {
        if ([pushedViewController isKindOfClass:[UINavigationController class]])
        {
            UINavigationController *navigationController = (UINavigationController*)pushedViewController;
            for (id subViewController in navigationController.viewControllers)
            {
                if ([subViewController respondsToSelector:@selector(destroy)])
                {
                    [subViewController destroy];
                }
            }
        }
        else if ([pushedViewController respondsToSelector:@selector(destroy)])
        {
            [(id)pushedViewController destroy];
        }

        pushedViewController = nil;
    }
}

- (void)reset
{
    // Remove observers
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)reloadData
{
    // Trigger a full table reloadData
    [self.tableView reloadData];
}

- (void)reloadDeviceWithCompletion:(void (^)(void))completion
{
    MXWeakify(self);
    [self.mainSession.matrixRestClient deviceByDeviceId:device.deviceId success:^(MXDevice *device) {
        MXStrongifyAndReturnIfNil(self);
        
        self->device = device;
        [self reloadData];
        completion();
        
    } failure:^(NSError *error) {
        NSLog(@"[ManageSessionVC] reloadDeviceWithCompletion failed. Error: %@", error);
        [self reloadData];
        completion();
    }];
}


#pragma mark - Segues

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Keep ref on destinationViewController
    [super prepareForSegue:segue sender:sender];

    // FIXME add night mode
}

#pragma mark - UITableView data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return SECTION_COUNT;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSInteger count = 0;

    switch (section)
    {
        case SECTION_SESSION_INFO:
            count = SESSION_INFO_COUNT;
            break;
        case SECTION_ACTION:
            count = ACTION_COUNT;
            break;
    }

    return count;
}

- (MXKTableViewCellWithLabelAndTextField*)getLabelAndTextFieldCell:(UITableView*)tableview forIndexPath:(NSIndexPath *)indexPath
{
    MXKTableViewCellWithLabelAndTextField *cell = [tableview dequeueReusableCellWithIdentifier:[MXKTableViewCellWithLabelAndTextField defaultReuseIdentifier] forIndexPath:indexPath];
    
    cell.mxkLabelLeadingConstraint.constant = cell.vc_separatorInset.left;
    cell.mxkTextFieldLeadingConstraint.constant = 16;
    cell.mxkTextFieldTrailingConstraint.constant = 15;
    
    cell.mxkLabel.textColor = ThemeService.shared.theme.textPrimaryColor;
    
    cell.mxkTextField.userInteractionEnabled = YES;
    cell.mxkTextField.borderStyle = UITextBorderStyleNone;
    cell.mxkTextField.textAlignment = NSTextAlignmentRight;
    cell.mxkTextField.textColor = ThemeService.shared.theme.textSecondaryColor;
    cell.mxkTextField.font = [UIFont systemFontOfSize:16];
    cell.mxkTextField.placeholder = nil;
    
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.accessoryView = nil;
    
    cell.alpha = 1.0f;
    cell.userInteractionEnabled = YES;
    
    [cell layoutIfNeeded];
    
    return cell;
}

- (MXKTableViewCellWithLabelAndSwitch*)getLabelAndSwitchCell:(UITableView*)tableview forIndexPath:(NSIndexPath *)indexPath
{
    MXKTableViewCellWithLabelAndSwitch *cell = [tableview dequeueReusableCellWithIdentifier:[MXKTableViewCellWithLabelAndSwitch defaultReuseIdentifier] forIndexPath:indexPath];

    cell.mxkLabelLeadingConstraint.constant = cell.vc_separatorInset.left;
    cell.mxkSwitchTrailingConstraint.constant = 15;

    cell.mxkLabel.textColor = ThemeService.shared.theme.textPrimaryColor;

    [cell.mxkSwitch removeTarget:self action:nil forControlEvents:UIControlEventTouchUpInside];

    // Force layout before reusing a cell (fix switch displayed outside the screen)
    [cell layoutIfNeeded];

    return cell;
}

- (MXKTableViewCell*)getDefaultTableViewCell:(UITableView*)tableView
{
    MXKTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:[MXKTableViewCell defaultReuseIdentifier]];
    if (!cell)
    {
        cell = [[MXKTableViewCell alloc] init];
    }
    else
    {
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.accessoryView = nil;
        cell.imageView.image = nil;
    }
    cell.textLabel.accessibilityIdentifier = nil;
    cell.textLabel.font = [UIFont systemFontOfSize:17];
    cell.textLabel.textColor = ThemeService.shared.theme.textPrimaryColor;
    cell.contentView.backgroundColor = UIColor.clearColor;

    return cell;
}

- (MXKTableViewCell*)trustCellWithDevice:(MXDevice*)device forTableView:(UITableView*)tableView
{
    MXKTableViewCell *cell = [self getDefaultTableViewCell:tableView];
    
    NSString *deviceId = device.deviceId;
    MXDeviceInfo *deviceInfo = [self.mainSession.crypto deviceWithDeviceId:deviceId ofUser:self.mainSession.myUser.userId];
    
    cell.textLabel.numberOfLines = 0;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

    if (deviceInfo.trustLevel.isVerified)
    {
        cell.textLabel.text = NSLocalizedStringFromTable(@"manage_session_trusted", @"Vector", nil);
        cell.imageView.image = [UIImage imageNamed:@"encryption_trusted"];
    }
    else
    {
        cell.textLabel.text = NSLocalizedStringFromTable(@"manage_session_not_trusted", @"Vector", nil);
        cell.imageView.image = [UIImage imageNamed:@"encryption_warning"];
    }

    return cell;
}

- (MXKTableViewCell*)descriptionCellForTableView:(UITableView*)tableView withText:(NSString*)text
{
    MXKTableViewCell *cell = [self getDefaultTableViewCell:tableView];
    cell.textLabel.text = text;
    cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    cell.textLabel.textColor = ThemeService.shared.theme.headerTextPrimaryColor;
    cell.textLabel.numberOfLines = 0;
    cell.contentView.backgroundColor = ThemeService.shared.theme.headerBackgroundColor;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    return cell;
}


- (MXKTableViewCellWithTextView*)textViewCellForTableView:(UITableView*)tableView atIndexPath:(NSIndexPath *)indexPath
{
    MXKTableViewCellWithTextView *textViewCell = [tableView dequeueReusableCellWithIdentifier:[MXKTableViewCellWithTextView defaultReuseIdentifier] forIndexPath:indexPath];

    textViewCell.mxkTextView.textColor = ThemeService.shared.theme.textPrimaryColor;
    textViewCell.mxkTextView.font = [UIFont systemFontOfSize:17];
    textViewCell.mxkTextView.backgroundColor = [UIColor clearColor];
    textViewCell.mxkTextViewLeadingConstraint.constant = tableView.vc_separatorInset.left;
    textViewCell.mxkTextViewTrailingConstraint.constant = tableView.vc_separatorInset.right;
    textViewCell.mxkTextView.accessibilityIdentifier = nil;

    return textViewCell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSInteger section = indexPath.section;
    NSInteger row = indexPath.row;

    // set the cell to a default value to avoid application crashes
    UITableViewCell *cell = [[UITableViewCell alloc] init];
    cell.backgroundColor = [UIColor redColor];

    switch (section)
    {
        case SECTION_SESSION_INFO:
            switch (row)
        {
            case SESSION_INFO_SESSION_NAME:
            {
                MXKTableViewCellWithLabelAndTextField *displaynameCell = [self getLabelAndTextFieldCell:tableView forIndexPath:indexPath];
                
                displaynameCell.mxkLabel.text = NSLocalizedStringFromTable(@"manage_session_name", @"Vector", nil);
                displaynameCell.mxkTextField.text = device.displayName;
                displaynameCell.mxkTextField.userInteractionEnabled = NO;
                displaynameCell.selectionStyle = UITableViewCellSelectionStyleDefault;
                
                cell = displaynameCell;
                break;
            }
            case SESSION_INFO_TRUST:
            {
                cell = [self trustCellWithDevice:device forTableView:tableView];
            }
                
        }
            break;
            
        case SECTION_ACTION:
            switch (row)
        {
            case ACTION_REMOVE_SESSION:
            {
                MXKTableViewCellWithButton *removeSessionBtnCell = [tableView dequeueReusableCellWithIdentifier:[MXKTableViewCellWithButton defaultReuseIdentifier]];
                
                if (!removeSessionBtnCell)
                {
                    removeSessionBtnCell = [[MXKTableViewCellWithButton alloc] init];
                }
                else
                {
                    // Fix https://github.com/vector-im/riot-ios/issues/1354
                    removeSessionBtnCell.mxkButton.titleLabel.text = nil;
                }
                
                NSString *btnTitle = NSLocalizedStringFromTable(@"manage_session_sign_out", @"Vector", nil);
                [removeSessionBtnCell.mxkButton setTitle:btnTitle forState:UIControlStateNormal];
                [removeSessionBtnCell.mxkButton setTitle:btnTitle forState:UIControlStateHighlighted];
                [removeSessionBtnCell.mxkButton setTintColor:ThemeService.shared.theme.warningColor];
                removeSessionBtnCell.mxkButton.titleLabel.font = [UIFont systemFontOfSize:17];
                removeSessionBtnCell.mxkButton.userInteractionEnabled = NO;
                removeSessionBtnCell.selectionStyle = UITableViewCellSelectionStyleDefault;
                
                cell = removeSessionBtnCell;
                break;
            }
        }
            break;
            
    }

    return cell;
}

- (nullable NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    switch (section)
    {
        case SECTION_SESSION_INFO:
            return NSLocalizedStringFromTable(@"manage_session_info", @"Vector", nil);
        case SECTION_ACTION:
            return @"";

    }

    return nil;
}

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section
{
    if ([view isKindOfClass:UITableViewHeaderFooterView.class])
    {
        // Customize label style
        UITableViewHeaderFooterView *tableViewHeaderFooterView = (UITableViewHeaderFooterView*)view;
        tableViewHeaderFooterView.textLabel.textColor = ThemeService.shared.theme.headerTextPrimaryColor;
    }
}


#pragma mark - UITableView delegate

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath;
{
    cell.backgroundColor = ThemeService.shared.theme.backgroundColor;

    if (cell.selectionStyle != UITableViewCellSelectionStyleNone)
    {
        // Update the selected background view
        if (ThemeService.shared.theme.selectedBackgroundColor)
        {
            cell.selectedBackgroundView = [[UIView alloc] init];
            cell.selectedBackgroundView.backgroundColor = ThemeService.shared.theme.selectedBackgroundColor;
        }
        else
        {
            if (tableView.style == UITableViewStylePlain)
            {
                cell.selectedBackgroundView = nil;
            }
            else
            {
                cell.selectedBackgroundView.backgroundColor = nil;
            }
        }
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    if (section == SECTION_SESSION_INFO)
    {
        return 44;
    }
    return 24;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    if (section == SECTION_SESSION_INFO)
    {
        return 0;
    }
    return 24;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.tableView == tableView)
    {
        NSInteger section = indexPath.section;
        NSInteger row = indexPath.row;
        
        switch (section)
        {
            case SECTION_SESSION_INFO:
                switch (row)
            {
                case SESSION_INFO_SESSION_NAME:
                    [self renameDevice];
                    break;
                case SESSION_INFO_TRUST:
                    [self showTrustForDevice:device];
                    break;
            }
                break;
                
            case SECTION_ACTION:
            {
                switch (row)
                {
                    case ACTION_REMOVE_SESSION:
                        [self removeDevice];
                        break;
                }
            }
        }
        
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
}

#pragma mark - actions

- (void)renameDevice
{
    // Prompt the user to enter a device name.
    [currentAlert dismissViewControllerAnimated:NO completion:nil];
    
    MXWeakify(self);
    currentAlert = [UIAlertController alertControllerWithTitle:[NSBundle mxk_localizedStringForKey:@"device_details_rename_prompt_title"]
                                                       message:[NSBundle mxk_localizedStringForKey:@"device_details_rename_prompt_message"] preferredStyle:UIAlertControllerStyleAlert];
    
    [currentAlert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        MXStrongifyAndReturnIfNil(self);
        textField.secureTextEntry = NO;
        textField.placeholder = nil;
        textField.keyboardType = UIKeyboardTypeDefault;
        textField.text = self->device.displayName;
    }];
    
    [currentAlert addAction:[UIAlertAction actionWithTitle:[NSBundle mxk_localizedStringForKey:@"cancel"]
                                                     style:UIAlertActionStyleDefault
                                                   handler:^(UIAlertAction * action)
                             {
                                 MXStrongifyAndReturnIfNil(self);
                                 self->currentAlert = nil;
                             }]];
    
    [currentAlert addAction:[UIAlertAction actionWithTitle:[NSBundle mxk_localizedStringForKey:@"ok"]
                                                     style:UIAlertActionStyleDefault
                                                   handler:^(UIAlertAction * action)
                             {
                                 MXStrongifyAndReturnIfNil(self);
                                 
                                 NSString *text = [self->currentAlert textFields].firstObject.text;
                                 self->currentAlert = nil;
                                 
                                 
                                 // Hot change
                                 self->device.displayName = text;
                                 [self reloadData];
                                 [self.activityIndicator startAnimating];

                                 [self.mainSession.matrixRestClient setDeviceName:text forDeviceId:self->device.deviceId success:^{
                                     [self reloadDeviceWithCompletion:^{
                                         [self.activityIndicator stopAnimating];
                                     }];
                                 } failure:^(NSError *error) {
                                     
                                     NSLog(@"[ManageSessionVC] Rename device (%@) failed", self->device.deviceId);
                                     [self reloadDeviceWithCompletion:^{
                                         [self.activityIndicator stopAnimating];
                                         [[AppDelegate theDelegate] showErrorAsAlert:error];
                                     }];
                                 }];
                                 
                             }]];
    
    [self presentViewController:currentAlert animated:YES completion:nil];
}

- (void)showTrustForDevice:(MXDevice *)device
{
    UserVerificationCoordinatorBridgePresenter *userVerificationCoordinatorBridgePresenter = [[UserVerificationCoordinatorBridgePresenter alloc] initWithPresenter:self
                                                                                                                                                           session:self.mainSession
                                                                                                                                                            userId:self.mainSession.myUser.userId
                                                                                                                                                   userDisplayName:nil
                                                                                                                                                          deviceId:device.deviceId];
    [userVerificationCoordinatorBridgePresenter start];
    self.userVerificationCoordinatorBridgePresenter = userVerificationCoordinatorBridgePresenter;
}

- (void)removeDevice
{
    // Get an authentication session to prepare device deletion
    [self.activityIndicator startAnimating];
    
    MXWeakify(self);
    [self.mainSession.matrixRestClient getSessionToDeleteDeviceByDeviceId:device.deviceId success:^(MXAuthenticationSession *authSession) {
        MXStrongifyAndReturnIfNil(self);
        
        // Check whether the password based type is supported
        BOOL isPasswordBasedTypeSupported = NO;
        for (MXLoginFlow *loginFlow in authSession.flows)
        {
            if ([loginFlow.type isEqualToString:kMXLoginFlowTypePassword] || [loginFlow.stages indexOfObject:kMXLoginFlowTypePassword] != NSNotFound)
            {
                isPasswordBasedTypeSupported = YES;
                break;
            }
        }
        
        if (isPasswordBasedTypeSupported && authSession.session)
        {
            // Prompt for a password
            [self->currentAlert dismissViewControllerAnimated:NO completion:nil];
            
            // Prompt the user before deleting the device.
            self->currentAlert = [UIAlertController alertControllerWithTitle:[NSBundle mxk_localizedStringForKey:@"device_details_delete_prompt_title"] message:[NSBundle mxk_localizedStringForKey:@"device_details_delete_prompt_message"] preferredStyle:UIAlertControllerStyleAlert];
            
            
            [self->currentAlert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
                
                textField.secureTextEntry = YES;
                textField.placeholder = nil;
                textField.keyboardType = UIKeyboardTypeDefault;
            }];
            
            [self->currentAlert addAction:[UIAlertAction actionWithTitle:[NSBundle mxk_localizedStringForKey:@"cancel"]
                                                                   style:UIAlertActionStyleDefault
                                                                 handler:^(UIAlertAction * action)
                                           {
                                               self->currentAlert = nil;
                                               [self.activityIndicator stopAnimating];
                                           }]];
            
            [self->currentAlert addAction:[UIAlertAction actionWithTitle:[NSBundle mxk_localizedStringForKey:@"submit"]
                                                                   style:UIAlertActionStyleDefault
                                                                 handler:^(UIAlertAction * action)
                                           {
                                               
                                               UITextField *textField = [self->currentAlert textFields].firstObject;
                                               self->currentAlert = nil;
                                               
                                               NSString *userId = self.mainSession.myUser.userId;
                                               NSDictionary *authParams;
                                               
                                               // Sanity check
                                               if (userId)
                                               {
                                                   authParams = @{@"session":authSession.session,
                                                                  @"user": userId,
                                                                  @"password": textField.text,
                                                                  @"type": kMXLoginFlowTypePassword};
                                                   
                                               }
                                               
                                               [self.mainSession.matrixRestClient deleteDeviceByDeviceId:self->device.deviceId authParams:authParams success:^{
                                                   [self.activityIndicator stopAnimating];
                                                   
                                                   // We cannot stay in this screen anymore
                                                   [self withdrawViewControllerAnimated:YES completion:nil];
                                               } failure:^(NSError *error) {
                                                   NSLog(@"[ManageSessionVC] Delete device (%@) failed", self->device.deviceId);
                                                   [self.activityIndicator stopAnimating];
                                                   [[AppDelegate theDelegate] showErrorAsAlert:error];
                                               }];
                                           }]];
            
            [self presentViewController:self->currentAlert animated:YES completion:nil];
        }
        else
        {
            NSLog(@"[ManageSessionVC] Delete device (%@) failed, auth session flow type is not supported", self->device.deviceId);
            [self.activityIndicator stopAnimating];
            //[[AppDelegate theDelegate] showErrorAsAlert:error];
        }
        
    } failure:^(NSError *error) {
        NSLog(@"[ManageSessionVC] Delete device (%@) failed, unable to get auth session", self->device.deviceId);
        [self.activityIndicator stopAnimating];
        [[AppDelegate theDelegate] showErrorAsAlert:error];
    }];
}

@end
