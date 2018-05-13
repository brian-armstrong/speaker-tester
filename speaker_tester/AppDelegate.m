#import "AppDelegate.h"
#import "TableViewController.h"

#import <AVFoundation/AVFoundation.h>

@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  NSError *error;

  if (![[AVAudioSession sharedInstance] setCategory: AVAudioSessionCategoryMultiRoute error: &error]) {
    NSLog(@"setCategory: %@", error);
  }
  
  if (![[AVAudioSession sharedInstance] setActive: YES error: &error]) {
    NSLog(@"setActive: %@", error);
  }

  TableViewController *controller = [[TableViewController alloc] initWithStyle:UITableViewStylePlain];
  UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:controller];
  
  self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
  self.window.rootViewController = nav;
  [self.window makeKeyAndVisible];
  
  return YES;
}

@end
