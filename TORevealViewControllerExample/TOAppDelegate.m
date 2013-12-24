//
//  TOAppDelegate.m
//  TORevealViewControllerExample
//
//  Created by Timothy OLIVER on 5/12/13.
//  Copyright (c) 2013 Timothy Oliver. All rights reserved.
//

#import "TOAppDelegate.h"
#import "TORevealViewController.h"
#import "TOViewController.h"

@implementation TOAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    TORevealViewController *rootController = [[TORevealViewController alloc] init];
    
    TOViewController *frontViewController = [TOViewController new];
    frontViewController.title = @"Front View Controller";
    frontViewController.navigationItem.rightBarButtonItem = rootController.hideFrontViewControllerButtonItem;
    rootController.frontViewController = [[UINavigationController alloc] initWithRootViewController:frontViewController];
    
    TOViewController *rearViewController = [TOViewController new];
    rearViewController.title = @"Rear View Controller";
    rearViewController.navigationItem.leftBarButtonItem = rootController.showFrontViewControllerButtonItem;
    rootController.rearViewController = [[UINavigationController alloc] initWithRootViewController:rearViewController];
    
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.backgroundColor = [UIColor blackColor];
    self.window.rootViewController = rootController;
    [self.window makeKeyAndVisible];
    
    return YES;
}

@end
