//
//  TORevealViewController.h
//
//  Copyright 2013 Timothy Oliver. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to
//  deal in the Software without restriction, including without limitation the
//  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
//  sell copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
//  OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR
//  IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#import <UIKit/UIKit.h>

@interface TORevealViewController : UIViewController

/* The smaller 'reveal' view controller that is laid over the top of the full-size rear one  */
@property (nonatomic, strong) UIViewController *frontViewController;

/* The main view controller that is visible for the majority of the time. It shrinks the more the reveal controller appears */
@property (nonatomic, strong) UIViewController *rearViewController;

/* Option for the rear view controller to zoom backwards slightly as the top view controller slides into view (YES by default) */
@property (nonatomic, assign) BOOL shrinkRearViewControllerAnimation;

/* Option to let the user present the front view controller using a swiping pan gesture. */
@property (nonatomic, assign) BOOL canPresentWithGesture;

/* On iOS 7, since the status bar is transparent, this option will fade in a UIView bar of the specified colour when opened. */
@property (nonatomic, strong) UIColor *statusBarBackgroundColor;

/* Bar button item that when tapped, will animate-reveal the front view controller */
@property (nonatomic, strong, readonly) UIBarButtonItem *showFrontViewControllerButtonItem;

/* Bar button item that will hide the front view controller */
@property (nonatomic, strong, readonly) UIBarButtonItem *hideFrontViewControllerButtonItem;

/* An overriding content size for the front view controller */
@property (nonatomic, assign) CGSize frontViewControllerContentSize;

/* An overriding vertical offset for the front view controller */
@property (nonatomic, assign) CGFloat frontViewControllerVerticalOffset;

/* Create a new instance of the reveal view controller with the foreground and background view controllers */
- (instancetype)initWithFrontViewController:(UIViewController *)frontViewController rearViewController:(UIViewController *)rearViewController;

/* Show the foreground view controller */
- (void)setFrontViewControllerHidden:(BOOL)hidden animated:(BOOL)animated;

@end

/* Optional methods the front view controller can implement to affect the placement of front view controller */
@interface UIViewController (TORevealViewController)

/* Children of reveal view controllers may access their parent reveal controller through here. */
- (TORevealViewController *)revealViewController;

/* If smaller than the height of display, this property will display how far down from the top the controller will be displayed */
- (CGFloat)verticalOffsetForRevealViewController;

/* Override the sizing of the foreground view controller */
- (CGSize)contentSizeForRevealViewController;

@end