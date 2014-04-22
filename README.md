 Social Media wrapper class to manage Twitter and Facebook interactions
 
 ***SETUP***
 
 - copy SocialMedia.h/m into the project
 - add the FacebookSDK to the project from here https://developers.facebook.com/docs/ios/
 
 In the AppDelegate, import SocialMedia.h and add the following:
 

 - (BOOL)application:(UIApplication *)application openURL:(NSURL *)url
 sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
 {
 if([url.absoluteString rangeOfString:@"fb"].location != NSNotFound) {
 return [[SocialMedia sharedInstance] handleOpenUrl:url];
 }
 return NO;
 }


 - (void)applicationDidBecomeActive:(UIApplication *)application
 {
 [[SocialMedia sharedInstance] handleDidBecomeActive];
 }
 

 
 ***HOW TO USE***
 
 For Twitter: we need to add sucess/fail notification listeners
 [[NSNotificationCenter defaultCenter] addObserver:self
 selector:@selector(loginWithTwitterSucessful:)
 name:kLoginSuccessNotification
 object:nil];
 [[NSNotificationCenter defaultCenter] addObserver:self
 selector:@selector(loginWithTwitterSucessful:)
 name:kLoginFailNotification
 object:nil];
 
 example usage as is follows:
 - (IBAction)loginWithTwitter:(id)sender
 {
 [[SocialMedia sharedInstance] loginWithTwitterAccounts];
 }
 
 - (IBAction)shareOnTwitter:(id)sender
 {
 [SocialMedia shareWithTwitter:@"Test share" withImage:nil andURL:nil showOn:self];
 }
 
 For Facebook, the login can be called as follows:
 - (IBAction)loginWithFacebook:(id)sender
 {
 [[SocialMedia sharedInstance]openSessionWithBasicInfo:^(NSError *error)
 {
 if(error) {
 [[[UIAlertView alloc] initWithTitle:@"Fail" message:error.description
 delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil] show];
 return;
 }
 [[[UIAlertView alloc] initWithTitle:@"Success" message:@"Authorization successful."
 delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil] show];
 
 }];
 }