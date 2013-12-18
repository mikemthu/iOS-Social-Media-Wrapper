
#import "SocialMedia.h"
#import <Twitter/Twitter.h>
#import <Accounts/Accounts.h>

#import <FacebookSDK/FacebookSDK.h>
#import <FacebookSDK/FBDialogs.h>
#import <FacebookSDK/FBWebDialogs.h>

@interface SocialMedia()
{
    
}
@property (nonatomic, copy) void(^openBlock)(NSError *error);
@property (nonatomic, copy) void(^permissionsBlock)(NSError *error);

@property (nonatomic,strong) NSArray* userAccounts;

@property (nonatomic,strong) ACAccount* selectedAccount;

@property (nonatomic, strong) NSString* twitterName;
@property (nonatomic, strong) NSString* twitterScreenName;
@property (nonatomic, strong) NSString* twitterBannerURLString;
@property (nonatomic, strong) NSString* twitterProfileImageStringURL;

@property(assign) BOOL isLoggedInTwitter;

@end

@implementation SocialMedia

@synthesize userAccounts,selectedAccount;
@synthesize isLoggedInTwitter;

+ (SocialMedia *)sharedInstance
{
    static SocialMedia *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [SocialMedia new];
        sharedInstance.isLoggedInTwitter = NO;
        [sharedInstance setSettings];
    });
    return sharedInstance;
}

#pragma mark Facebook
#pragma mark -

- (void)setSettings
{
    [FBSettings setDefaultAppID:FacebookAppId()];
}

- (BOOL)handleOpenUrl:(NSURL*)url
{
    return [FBSession.activeSession handleOpenURL:url];
}

- (void)handleDidBecomeActive
{
    [FBSession.activeSession handleDidBecomeActive];
}

NSString *NSStringFromFBSessionState(FBSessionState state)
{
    switch (state) {
        case FBSessionStateClosed:
            return @"FBSessionStateClosed";
        case FBSessionStateClosedLoginFailed:
            return @"FBSessionStateClosedLoginFailed";
        case FBSessionStateCreated:
            return @"FBSessionStateCreated";
        case FBSessionStateCreatedOpening:
            return @"FBSessionStateCreatedOpening";
        case FBSessionStateCreatedTokenLoaded:
            return @"FBSessionStateCreatedTokenLoaded";
        case FBSessionStateOpen:
            return @"FBSessionStateOpen";
        case FBSessionStateOpenTokenExtended:
            return @"FBSessionStateOpenTokenExtended";
    }
    return @"Not Found";
}

- (void)openSessionWithBasicInfoThenRequestPublishPermissions:(void(^)(NSError *error))completionBlock
{
    [self openSessionWithBasicInfo:^(NSError *error) {
        if(error) {
            completionBlock(error);
            return;
        }
        
        [self requestPublishPermissions:^(NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock(error);
            });
        }];
    }];
}

- (void)openSessionWithBasicInfo:(void(^)(NSError *error))completionBlock
{
    if([[FBSession activeSession] isOpen]) {
        completionBlock(nil);
        return;
    }
    
    self.openBlock = completionBlock;
    
    [FBSession openActiveSessionWithReadPermissions:@[@"basic_info"] allowLoginUI:YES completionHandler:^(FBSession *session, FBSessionState status, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self sessionStateChanged:session state:status error:error open:YES permissions:NO];
        });
    }];
}

- (void)sessionStateChanged:(FBSession *)session state:(FBSessionState)state error:(NSError *)error open:(BOOL)open permissions:(BOOL)permissions
{
    if(self.openBlock && open) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.openBlock(error);
            self.openBlock = nil;
        });
    }
    else if(self.permissionsBlock && permissions) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.permissionsBlock(error);
            self.permissionsBlock = nil;
        });
    }
}

- (void)openSessionWithBasicInfoThenRequestPublishPermissionsAndGetAudienceType:(void(^)(NSError *error, FacebookAudienceType))completionBlock
{
    [self openSessionWithBasicInfoThenRequestPublishPermissions:^(NSError *error) {
        if(error) {
            completionBlock(error, 0);
            return;
        }
        
        [self getAppAudienceType:^(FacebookAudienceType audienceType, NSError *error) {
            if(error) {
                completionBlock(error, 0);
                return;
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock(nil, audienceType);
            });
        }];
    }];
}

- (void)getUserInfo:(void(^)(id<FBGraphUser> user, NSError *error))completionBlock
{
    [[FBRequest requestForMe] startWithCompletionHandler:
     ^(FBRequestConnection *connection, NSDictionary<FBGraphUser> *user, NSError *error) {
         completionBlock(user, error);
     }];
}

- (void)getFriends:(void(^)(NSArray *friends, NSError *error))completionBlock
{
    FBRequest* friendsRequest = [FBRequest requestForMyFriends];
    friendsRequest.session = [FBSession activeSession];
    [friendsRequest startWithCompletionHandler: ^(FBRequestConnection *connection, NSDictionary* result, NSError *error) {
        if(error) {
            completionBlock(nil, error);
            return;
        }
        
        NSArray* friends = result[@"data"];
        completionBlock(friends, nil);
    }];
}

- (void)showAppRequestDialogueWithMessage:(NSString*)message toUserId:(NSString*)userId
{
    [FBWebDialogs presentDialogModallyWithSession:[FBSession activeSession] dialog:@"apprequests"
                                       parameters:@{@"to" : userId, @"message" : message}
                                          handler:^(FBWebDialogResult result, NSURL *resultURL, NSError *error) {
                                              
                                          }];
}

- (NSString*)accessToken
{
    return [[[FBSession activeSession] accessTokenData] accessToken];
}

- (void)logout
{
    [FBSession.activeSession closeAndClearTokenInformation];
}

FacebookAudienceType AudienceTypeForValue(NSString *value)
{
    if([value isEqualToString:@"ALL_FRIENDS"])        return FacebookAudienceTypeFriends;
    if([value isEqualToString:@"SELF"])               return FacebookAudienceTypeSelf;
    if([value isEqualToString:@"EVERYONE"])           return FacebookAudienceTypeEveryone;
    if([value isEqualToString:@"FRIENDS_OF_FRIENDS"]) return FacebookAudienceTypeFriends;
    if([value isEqualToString:@"NO_FRIENDS"])         return FacebookAudienceTypeSelf;
    return FacebookAudienceTypeSelf;
}

BOOL FacebookAudienceTypeIsRestricted(FacebookAudienceType type)
{
    return type == FacebookAudienceTypeSelf;
}

- (void)getAppAudienceType:(void(^)(FacebookAudienceType audienceType, NSError *error))completionBlock
{
    if(![[[FBSession activeSession] accessTokenData] accessToken]) {
        completionBlock(0, [NSError new]);
        return;
    }
    
    NSString *query = @"SELECT value FROM privacy_setting WHERE name = 'default_stream_privacy'";
    NSDictionary *queryParam = @{ @"q": query, @"access_token" :  [[[FBSession activeSession] accessTokenData] accessToken]};
    
    [FBRequestConnection startWithGraphPath:@"/fql" parameters:queryParam HTTPMethod:@"GET" completionHandler:^(FBRequestConnection *connection, id result, NSError *error) {
        if(error) {
            completionBlock(0, error);
            return;
        }
        
        FBGraphObject *object = result;
        id type = [object objectForKey:@"data"][0][@"value"];
        completionBlock(AudienceTypeForValue(type), nil);
    }];
}


static NSString *const publish_actions = @"publish_actions";

- (void)requestPublishPermissions:(void(^)(NSError *error))completionBlock
{
    if([[[FBSession activeSession] permissions] indexOfObject:publish_actions] != NSNotFound) {
        completionBlock(nil);
        return;
    }
    
    if([[FBSession activeSession] isOpen] == NO) {
        // error
        [[[UIAlertView alloc] initWithTitle:@"Error" message:@"Attempting to request publish permissions on unopened session." delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil] show];
        return;
    }
    
    self.permissionsBlock = completionBlock;
    
    [FBSession.activeSession requestNewPublishPermissions:@[publish_actions] defaultAudience:FBSessionDefaultAudienceEveryone completionHandler:^(FBSession *session, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self sessionStateChanged:session state:session.state error:error open:NO permissions:YES];
        });
    }];
}

+ (void)shareFacebook:(NSString*)initialText withImage:(UIImage*)imageToPost andURL:(NSURL*)urlToPost showOn:(UIViewController *)callerViewController
{
    SLComposeViewController *controller = [SLComposeViewController composeViewControllerForServiceType:SLServiceTypeFacebook];
    [controller setInitialText:initialText];
    [controller addImage:imageToPost];
    [controller addURL:urlToPost];
    
    [callerViewController presentViewController:controller animated:YES completion:^{
        
    }];
}

#pragma mark Twitter
#pragma mark -

+ (void)shareWithTwitter:(NSString*)initialText withImage:(UIImage*)imageToPost andURL:(NSURL*)urlToPost showOn:(UIViewController *)callerViewController
{
    SLComposeViewController *controller = [SLComposeViewController composeViewControllerForServiceType:SLServiceTypeTwitter];
    [controller setInitialText:initialText];
    [controller addImage:imageToPost];
    [controller addURL:urlToPost];
    
    [callerViewController presentViewController:controller animated:YES completion:^{
        
    }];
}

- (NSString*)getTwitterUserName
{
    return selectedAccount.username;
}

- (NSString*)getTwitterUserFullName
{
    return selectedAccount.userFullName;
}

- (UIImage*)getTwitterProfileImage
{
    return [self getImageForURLString:self.twitterProfileImageStringURL];
}

- (UIImage*)getTwitterBannerImage
{
    return [self getImageForURLString:self.twitterBannerURLString];
}

- (void)getActiveTwitterAccounts:(void (^)(NSArray* accountsArray))completionBlock;
{
    __block NSArray* accountsArray = nil;
    ACAccountStore *accountStore = [[ACAccountStore alloc] init];
    ACAccountType *accountType = [accountStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];
    [accountStore requestAccessToAccountsWithType:accountType options:nil completion:^(BOOL granted, NSError *error){
        if (granted)
        {
            accountsArray = [accountStore accountsWithAccountType:accountType];
            if (completionBlock != nil) {
                completionBlock(accountsArray);
            }
        } else
        {
            [[NSNotificationCenter defaultCenter]
             postNotificationName:kLoginFailNotification
             object:@"No access granted"];
        }
    }];
}

- (void)GetUserInfo
{
    SLRequest *twitterInfoRequest = [SLRequest requestForServiceType:SLServiceTypeTwitter
                                                       requestMethod:SLRequestMethodGET URL:[NSURL URLWithString:@"https://api.twitter.com/1.1/users/show.json"]
                                                          parameters:[NSDictionary dictionaryWithObject:selectedAccount.username forKey:@"screen_name"]];
    [twitterInfoRequest setAccount:selectedAccount];
    [twitterInfoRequest performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error)
     {
         dispatch_async(dispatch_get_main_queue(), ^{
             if ([urlResponse statusCode] == 429)
             {
                 NSLog(@"Rate limit reached");
                 return;
             }
             if (error)
             {
                 NSLog(@"Error: %@", error.localizedDescription);
                 return;
             }
             if (responseData)
             {
                 NSError *error = nil;
                 NSArray *TWData = [NSJSONSerialization JSONObjectWithData:responseData options:NSJSONReadingMutableLeaves error:&error];
                 self.twitterScreenName = [(NSDictionary *)TWData objectForKey:@"screen_name"];
                 self.twitterName = [(NSDictionary *)TWData objectForKey:@"name"];
                 NSString *profileImageStringURL = [(NSDictionary *)TWData objectForKey:@"profile_image_url_https"];
                 NSString *bannerImageStringURL =[(NSDictionary *)TWData objectForKey:@"profile_banner_url"];
                 self.twitterProfileImageStringURL = [profileImageStringURL stringByReplacingOccurrencesOfString:@"_normal" withString:@""];
                 if (bannerImageStringURL)
                 {
                     self.twitterBannerURLString = [NSString stringWithFormat:@"%@/mobile_retina", bannerImageStringURL];
                 }
             }
         });
     }];
}

- (void)loginWithTwitterAccounts
{
    [self getActiveTwitterAccounts:^(NSArray* accounts){
        if (accounts.count >1)
        {
            self.userAccounts = accounts;
            [self performSelectorOnMainThread:@selector(showActionSheet:) withObject:accounts waitUntilDone:NO];
        }
        else
        {
            self.selectedAccount = (ACAccount*)[userAccounts objectAtIndex:0];
            [self GetUserInfo];
            self.isLoggedInTwitter = YES;
            [[NSNotificationCenter defaultCenter]
             postNotificationName:kLoginSuccessNotification
             object:selectedAccount.username];
        }
    }];
}

- (void)showActionSheet:(NSArray*) accounts
{
    UIActionSheet *asAccounts = [[UIActionSheet alloc] initWithTitle:@"Select an account to login with"
                                                            delegate:self
                                                   cancelButtonTitle:nil
                                              destructiveButtonTitle:nil
                                                   otherButtonTitles: nil];
    
    for (int i=0; i<[accounts count]; i++) {
        ACAccount *acct = [accounts objectAtIndex:i];
        [asAccounts addButtonWithTitle:[acct username]];
    }
    [asAccounts addButtonWithTitle:@"Cancel"];
    asAccounts.cancelButtonIndex = accounts.count;
    [asAccounts showInView:[[UIApplication sharedApplication] keyWindow]];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex != [userAccounts count])
    {
        self.selectedAccount = (ACAccount*)[userAccounts objectAtIndex:buttonIndex];
        [self GetUserInfo];
        self.isLoggedInTwitter = YES;
        [[NSNotificationCenter defaultCenter]
         postNotificationName:kLoginSuccessNotification
         object:selectedAccount.username];
    }
    else
    {
        NSLog(@"Cancel");
    }
}

#pragma mark Helpers
#pragma mark -

NSString *FacebookAppId()
{
    return [[NSBundle mainBundle] objectForInfoDictionaryKey:@"FacebookAppID"];
}

- (UIImage*)getImageForURLString:(NSString *)urlString;
{
    NSURL *url = [NSURL URLWithString:urlString];
    NSData *data = [NSData dataWithContentsOfURL:url];
    return [UIImage imageWithData:data];
}

@end
