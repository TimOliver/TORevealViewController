//
//  TORevealViewController.m
//
//  Copyright 2014 Timothy Oliver. All rights reserved.
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

#define REVEAL_VIEW_CONTROLLER_DEFAULT_FRONT_SIZE CGSizeMake(320.0f, self.view.bounds.size.height)

#ifndef NSFoundationVersionNumber_iOS_6_1
#define NSFoundationVersionNumber_iOS_6_1 993.00
#endif

#import <QuartzCore/QuartzCore.h>
#import "TORevealViewController.h"

@interface TORevealViewController () <UIGestureRecognizerDelegate>

/* The current extent that the front view controller is visible (0.0 to 1.0) */
@property (nonatomic, assign) CGFloat frontControllerOffsetRatio;

/* Gesture Recognizer to handle any panning gestures to display the front view controller */
@property (nonatomic, strong) UIPanGestureRecognizer *panGestureRecognizer;

/* Gesture Recognizer to recognize any taps that will trigger the hiding of the front view controller */
@property (nonatomic, strong) UITapGestureRecognizer *tapGestureRecognizer;

/* Linked to the main loop, this display link will monitor screen updates when we need to tie some views to an animation */
@property (nonatomic, strong) CADisplayLink *displayLink;

/* A default bar button item that can be used to trigger the displaying of the front view controller */
@property (nonatomic, strong, readwrite) UIBarButtonItem *showFrontViewControllerButtonItem;

/* A default bar button item that can be used to trigger the displaying of the front view controller */
@property (nonatomic, strong, readwrite) UIBarButtonItem *hideFrontViewControllerButtonItem;

/* A black overlay that is applied to the rear view controller as the front one slides in over the top. */
@property (nonatomic, strong) UIView *blackOverlayView;

/* A UIView that is optionally displayed behind the status bar on iOS 7 to ensure its content is still legible */
@property (nonatomic, strong) UIView *statusBarUnderlayView;

/* A property to keep track of the translation distance of the pan gesture recognizer */
@property (nonatomic, assign) CGFloat panTranslationOriginX;

- (void)setup;

/* Work out the frame of the front view controller, given current state. */
- (CGRect)frameForFrontViewControllerHidden:(BOOL)hidden;

/* Reset the transform and lay out the rear view controller */
- (void)layoutRearViewController;

/* Feedback methods for recognized gesture recognizers */
- (void)panGestureRecognized:(UIPanGestureRecognizer *)panGestureRecognizer;
- (void)tapGestureRecognized:(UITapGestureRecognizer *)tapGestureRecognizer;

/* Whether done on init, or down the track, these methods set up the two child view controllers */
- (void)setUpFrontViewController;
- (void)setUpRearViewController;

/* Triggered when an animation redraws to the screen */
- (void)updateDisplayLinkContent;

/* Used to layout all content as they currently should be */
- (void)layoutContent;

/* Start observing the v-sync refresh of the screen (so we can redraw any content as needed) */
- (void)startObservingVSyncRefresh;
- (void)stopObservingVSyncRefresh;

/* Callback for when the visiblity state of the front view controller is toggled. */
- (void)showFrontViewControllerButtonTapped:(id)sender;
- (void)hideFrontViewControllerButtonTapped:(id)sender;

/* Reset the navigation bars on any UINavigationController children. */
- (void)resetNavigationControllerChildren;

@end

@implementation TORevealViewController

- (instancetype)init
{
    if (self = [super init])
        [self setup];
    
    return self;
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])
        [self setup];
    
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder])
        [self setup];
    
    return self;
}

- (instancetype)initWithFrontViewController:(UIViewController *)frontViewController rearViewController:(UIViewController *)rearViewController
{
    if (self = [self init])
    {
        _frontViewController = frontViewController;
        _rearViewController = rearViewController;
    }
    
    return self;
}

- (void)setup
{
    _shrinkRearViewControllerAnimation = YES;
    _canPresentWithGesture = YES;
}

- (void)loadView
{
    self.view = [[UIView alloc] initWithFrame:[UIScreen mainScreen].applicationFrame];
    self.view.opaque = YES;
    self.view.backgroundColor = [UIColor blackColor];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    //set up the front and the rear view controllers
    [self setUpRearViewController];
    [self setUpFrontViewController];
    
    //add the black overlay view
    self.blackOverlayView = [[UIView alloc] initWithFrame:self.view.bounds];
    self.blackOverlayView.alpha = 0.0f;
    self.blackOverlayView.backgroundColor = [UIColor blackColor];
    self.blackOverlayView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    [self.view insertSubview:self.blackOverlayView aboveSubview:self.rearViewController.view];
    
    //add the pan gesture recognizer to ourselves
    self.panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panGestureRecognized:)];
    self.panGestureRecognizer.delegate = self;
    [self.view addGestureRecognizer:self.panGestureRecognizer];
    
    //add the tap gesture recognizer
    self.tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapGestureRecognized:)];
    self.tapGestureRecognizer.delegate = self;
    [self.view addGestureRecognizer:self.tapGestureRecognizer];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    CGRect frame = self.frontViewController.view.frame;
    BOOL isHidden = CGRectGetMinX(frame) < 0.0f - FLT_EPSILON;
    
    frame = [self frameForFrontViewControllerHidden:isHidden];
    if (isHidden == NO)
        frame.origin.x = 0.0f;
    
    self.frontViewController.view.frame = frame;
}

#pragma mark -
#pragma mark Setting up
- (CGRect)frameForFrontViewControllerHidden:(BOOL)hidden
{
    CGRect frame = CGRectZero;
    
    //See if the front view controller, or any of its children implement the size method
    UIViewController *targetViewController = self.frontViewController;
    if ([targetViewController respondsToSelector:@selector(contentSizeForRevealViewController)] == NO)
    {
        for (UIViewController *childController in targetViewController.childViewControllers)
        {
            if ([childController respondsToSelector:@selector(contentSizeForRevealViewController)])
            {
                targetViewController = childController;
                break;
            }
        }
    }
    
    //set the size
    if (self.frontViewControllerContentSize.width > 0.0f + FLT_EPSILON)
        frame.size = self.frontViewControllerContentSize;
    else if ([targetViewController respondsToSelector:@selector(contentSizeForRevealViewController)])
        frame.size = [targetViewController contentSizeForRevealViewController];
    else
        frame.size = REVEAL_VIEW_CONTROLLER_DEFAULT_FRONT_SIZE;
    
    //make sure the size isn't bigger than the view space
    frame.size.height = MIN(CGRectGetHeight(frame), CGRectGetHeight(self.view.bounds));
    
    //set the vertical co-ordinates
    if (self.frontViewControllerVerticalOffset > 0.0f)
        frame.origin.y = self.frontViewControllerVerticalOffset;
    else if ([targetViewController respondsToSelector:@selector(verticalOffsetForRevealViewController)])
        frame.origin.y = [targetViewController verticalOffsetForRevealViewController];
    else
        frame.origin.y = 0.0f;
    
    //hidden by default (But can be overridden by the calling method)
    if (hidden) {
        frame.origin.x = -(CGRectGetWidth(frame));
        self.frontControllerOffsetRatio = 0.0f;
    }
    else {
        self.frontControllerOffsetRatio = 1.0f;
        frame.origin.x = 0.0f;
    }
        
    return frame;
}

- (void)layoutRearViewController
{
    if (self.shrinkRearViewControllerAnimation) {
        self.rearViewController.view.layer.transform = CATransform3DScale(CATransform3DIdentity, 1.0f, 1.0f, 1.0f);
        self.rearViewController.view.frame = self.view.bounds;
    }
    
    [self layoutContent];
}

- (void)setUpFrontViewController
{
    if (self.frontViewController == nil)
        return;
    
    //add the new one to the hierarchy
    [self addChildViewController:self.frontViewController];
    
    //set up the view size
    CGRect frame = [self frameForFrontViewControllerHidden:YES];
    
    self.frontViewController.view.frame = frame;
    self.frontViewController.view.hidden = YES;
    
    //add to the main view
    [self.view addSubview:self.frontViewController.view];
    
    // if we're iOS 6 or below, round the edges
    if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_6_1)
    {
        UIView *frontView = self.frontViewController.view;
        
        frontView.layer.masksToBounds = YES;
        
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
            frontView.layer.cornerRadius = 5.0f;
        else
            frontView.layer.cornerRadius = 2.0f;
    }
    
    if (self.statusBarUnderlayView)
        [self.view bringSubviewToFront:self.statusBarUnderlayView];
}

- (void)setUpRearViewController
{
    if (self.rearViewController == nil)
        return;
    
    //add the new one to the hierarchy
    [self addChildViewController:self.rearViewController];
    
    //set up the view size
    self.rearViewController.view.frame = self.view.bounds;
    
    //add to the main view
        [self.view insertSubview:self.rearViewController.view atIndex:0];
    
    //re-position the black overlay
    if (self.blackOverlayView)
        [self.view insertSubview:self.blackOverlayView aboveSubview:self.rearViewController.view];
    
    //bring the overlay view to the front
    if (self.statusBarUnderlayView)
        [self.view bringSubviewToFront:self.statusBarUnderlayView];
}

#pragma mark -
#pragma mark Event Handling
- (void)showFrontViewControllerButtonTapped:(id)sender
{
    [self setFrontViewControllerHidden:NO animated:YES];
}

- (void)hideFrontViewControllerButtonTapped:(id)sender
{
    [self setFrontViewControllerHidden:YES animated:YES];
}

#pragma mark -
#pragma mark Animation Handling
- (void)startObservingVSyncRefresh
{
    if (self.displayLink)
        return;
    
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateDisplayLinkContent)];
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)stopObservingVSyncRefresh
{   
    [self.displayLink removeFromRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    [self.displayLink invalidate];
    self.displayLink = nil;
}

- (void)updateDisplayLinkContent
{
    //Work out where the front view controller is positioned, even if it's in the middle of an animation sequence
    CGRect frame = [(CALayer *)self.frontViewController.view.layer.presentationLayer frame];
    if (frame.size.width < 0.0f + FLT_EPSILON)
        return;
    
    //Work out as a percentage, at what completion state of the animation it's at
    CGFloat completionRatio = 1.0f - (frame.origin.x / (-frame.size.width));
    completionRatio = MIN(completionRatio, 1.0f);
    completionRatio = MAX(completionRatio, 0.0f);
    
    self.frontControllerOffsetRatio = completionRatio;
    
    [self layoutContent];
}

- (void)layoutContent
{
    CGFloat completionRatio = self.frontControllerOffsetRatio;
    
    CGSize frontControllerSize = self.frontViewController.view.frame.size;
    
    if (self.statusBarUnderlayView)
        self.statusBarUnderlayView.alpha = completionRatio;
    
    //change the opacity of the black overlay to match the current completion percentage
    self.blackOverlayView.alpha = MIN(completionRatio * 0.55f, 0.55f);
    
    //if the front view controller is completely off-screen, hide it
    if (self.frontControllerOffsetRatio <= 0.0f + FLT_EPSILON)
        self.frontViewController.view.hidden = YES;
    else
        self.frontViewController.view.hidden = NO;
    
    //if the front view controller has completeley obscured the rear view controller, hide it
    if (CGSizeEqualToSize(frontControllerSize, self.view.bounds.size) && completionRatio >= 1.0f - FLT_EPSILON)
    {
        [self.rearViewController.view removeFromSuperview];
        [self.blackOverlayView removeFromSuperview];
    }
    else
    {
        if (self.rearViewController.view.superview == nil) {
            //reset the transform and the size of the view before inserting it in, or else iOS 7 UINavigationControllers
            //will ignore the status bar
            self.rearViewController.view.layer.transform = CATransform3DScale(CATransform3DIdentity, 1.0f, 1.0f, 1.0f);
            self.rearViewController.view.frame = self.view.bounds;
            [self.view insertSubview:self.rearViewController.view atIndex:0];
            
            [self.view insertSubview:self.blackOverlayView aboveSubview:self.rearViewController.view];
            self.blackOverlayView.frame = self.view.bounds;
            
            [self resetNavigationControllerChildren];
        }
    }
    
    //change the sizing of the rear layer's transform
    if (self.shrinkRearViewControllerAnimation) {
        
        CGFloat scale = 0.15f;
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
            scale = 0.06f;
        
        CGFloat transformScale = 1.0f - (scale * completionRatio);
        self.rearViewController.view.layer.transform = CATransform3DScale(CATransform3DIdentity, transformScale, transformScale, transformScale);
    }
}

- (void)resetNavigationControllerChildren
{
    if ([self.frontViewController isKindOfClass:[UINavigationController class]])
    {
        //force the navigation bar to reset itself by hiding and re-showing it
        UINavigationController *navController = (UINavigationController *)self.frontViewController;
        if (navController.navigationBarHidden == NO)
        {
            [navController setNavigationBarHidden:YES animated:NO];
            [navController setNavigationBarHidden:NO animated:NO];
        }
    }
    
    if ([self.rearViewController isKindOfClass:[UINavigationController class]])
    {
        //force the navigation bar to reset itself by hiding and re-showing it
        UINavigationController *navController = (UINavigationController *)self.rearViewController;
        if (navController.navigationBarHidden == NO)
        {
            [navController setNavigationBarHidden:YES animated:NO];
            [navController setNavigationBarHidden:NO animated:NO];
        }
    }
}

- (void)setFrontViewControllerHidden:(BOOL)hidden animated:(BOOL)animated
{
    CGRect frame = self.frontViewController.view.frame;
    
    if (hidden) {
        frame.origin.x = -(CGRectGetWidth(frame));
        self.frontControllerOffsetRatio = 0.0f;
    }
    else {
        frame.origin.x = 0.0f;
        self.frontControllerOffsetRatio = 1.0f;
    }
        
    if (animated == NO)
    {
        self.frontViewController.view.frame = frame;
        [self layoutContent];
    }
    else
    {
        CGPoint translatedFromPoint = self.frontViewController.view.frame.origin;
        CGPoint translatedToPoint = frame.origin;
        
        translatedFromPoint.x += CGRectGetWidth(frame) * 0.5f;
        translatedFromPoint.y += CGRectGetHeight(frame) * 0.5f;
        
        translatedToPoint.x += CGRectGetWidth(frame) * 0.5f;
        translatedToPoint.y += CGRectGetHeight(frame) * 0.5f;
        
        CABasicAnimation *panAnimation = [CABasicAnimation animationWithKeyPath:@"position"];
        panAnimation.fromValue = [NSValue valueWithCGPoint:translatedFromPoint];
        panAnimation.toValue = [NSValue valueWithCGPoint:translatedToPoint];
        panAnimation.duration = 0.35f;
        panAnimation.timingFunction = [CAMediaTimingFunction functionWithControlPoints:0.35f :0.91f :0.56f :1.0f];
        panAnimation.delegate = self;
        [self.frontViewController.view.layer addAnimation:panAnimation forKey:@"position"];
        self.frontViewController.view.frame = frame;
        
        [self startObservingVSyncRefresh];
    }
}

- (void)animationDidStop:(CAAnimation *)anim finished:(BOOL)flag
{
    if (flag == NO)
        return;
    
    //stop observing the frame refresh link
    [self stopObservingVSyncRefresh];
    
    //lock in one more poll of the completion ratio
    CGRect frame = self.frontViewController.view.frame;
    self.frontControllerOffsetRatio = 1.0f - (frame.origin.x / (-frame.size.width));
    [self layoutContent];
}

#pragma mark -
#pragma mark Gesture Recognition
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer == self.panGestureRecognizer && self.canPresentWithGesture)
    {
        CGPoint translation = [self.panGestureRecognizer translationInView:self.view];
        CGRect frame = self.frontViewController.view.frame;
        
        // if the front view is hidden, only activate if travelling to the right
        if (CGRectGetMinX(frame) <= -(CGRectGetWidth(frame) + FLT_EPSILON))
        {
            if (translation.x > 0.0f + FLT_EPSILON && fabs(translation.y) < fabs(translation.x))
                return YES;
        }
        //only recognize the pan if it's horizontal
        else {
            if (fabs(translation.y) < fabs(translation.x))
                return YES;
        }
    }
    else if (self.frontViewControllerIsVisible && gestureRecognizer == self.tapGestureRecognizer)
    {
        CGRect frame = [(CALayer *)self.frontViewController.view.layer.presentationLayer frame];
        
        //if front view is currently visible and
        //if we tapped outside the front view controller
        CGPoint tapPoint = [gestureRecognizer locationInView:self.view];
        if (CGRectIntersectsRect(frame, self.view.bounds) && !CGRectContainsPoint(frame, tapPoint))
            return YES;
    }
    
    return NO;
}

- (void)panGestureRecognized:(UIPanGestureRecognizer *)panGestureRecognizer
{
    //get the latest translation info
    CGFloat offset = [panGestureRecognizer translationInView:self.view].x;
    CGRect frame = [(CALayer *)self.frontViewController.view.layer.presentationLayer frame];
    
    //the pan gesture recognizer doesn't store the offset delta, but the translation SINCE tapping down
    //so to work this out, we need to save the original position of the front view controller when we started
    if (panGestureRecognizer.state == UIGestureRecognizerStateBegan)
    {
        //if we swiped mid-animation, cancel the animation and set the new origin to the frame canceled at
        if ([self.frontViewController.view.layer animationForKey:@"position"])
        {
            [self.frontViewController.view.layer removeAllAnimations];
            self.frontViewController.view.frame = frame;
        }
        
        self.panTranslationOriginX = frame.origin.x;
    }
    
    //work out the new frame of the front view controller
    frame.origin.x = self.panTranslationOriginX + offset;
    
    //cap it so it can't go furthur to the left
    frame.origin.x = MAX(frame.origin.x, -frame.size.width);
    frame.origin.x = MIN(frame.origin.x, 0.0f);
    
    //save the offset as a ratio for manual updates later
    self.frontViewController.view.frame = frame;
    
    //save the current position as a ratio
    self.frontControllerOffsetRatio = 1.0f - (frame.origin.x / (-frame.size.width));
    
    //update the rear view controller's display
    [self layoutContent];
    
    //if the gesture is ending, see if we need to animate out the rest
    if (panGestureRecognizer.state == UIGestureRecognizerStateEnded)
    {
        //get the velocity we're travelling at
        CGFloat velocityX = [panGestureRecognizer velocityInView:self.view].x;
        
        //see how much of the view is visible on screen at this very moment
        CGFloat visibleRatio = 1.0f - (frame.origin.x / -frame.size.width);
        
        //moving fast to the left
        if (velocityX > 300.0f)
        {
            [self setFrontViewControllerHidden:NO animated:YES];
        }
        else if (velocityX < -300.0f) //moving fast to the right
        {
            [self setFrontViewControllerHidden:YES animated:YES];
        }
        else
        {
            //this means the velocity was very slow, so see how much we've completed, and head in that direction
            if (visibleRatio > 0.5f)
                [self setFrontViewControllerHidden:NO animated:YES];
            else
                [self setFrontViewControllerHidden:YES animated:YES];
        }
    }
}

- (void)tapGestureRecognized:(UITapGestureRecognizer *)tapGestureRecognizer
{
    [self setFrontViewControllerHidden:YES animated:YES];
}

#pragma mark -
#pragma mark Screen Rotation Handling
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    return [self.rearViewController shouldAutorotateToInterfaceOrientation:toInterfaceOrientation];
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    //inform all of the children view controllers that we're going to rotate
    for (UIViewController *childController in self.childViewControllers)
        [childController willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
    
    //set the new frame for the front view controller based on the new orientation
    CGRect frame = [self frameForFrontViewControllerHidden:!self.frontViewControllerIsVisible];
    self.frontViewController.view.frame = frame;
    
    //reset the size of the rear view controller
    if (self.rearViewController.view.superview)
        [self layoutRearViewController];

    //layout all of the content
    [self layoutContent];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    //reset the frame of the front view controller
    if (self.frontViewControllerIsVisible) {
        self.frontViewController.view.frame = [self frameForFrontViewControllerHidden:NO];
    }
    
    //inform all of the children view controllers that we've rotated
    for (UIViewController *childController in self.childViewControllers)
        [childController didRotateFromInterfaceOrientation:fromInterfaceOrientation];
    
    //layout the content
    [self layoutContent];
}

#pragma mark -
#pragma mark Accessors
- (UIBarButtonItem *)showFrontViewControllerButtonItem
{
    if (_showFrontViewControllerButtonItem == nil)
        _showFrontViewControllerButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Menu" style:UIBarButtonItemStylePlain target:self action:@selector(showFrontViewControllerButtonTapped:)];
    
    return _showFrontViewControllerButtonItem;
}

- (UIBarButtonItem *)hideFrontViewControllerButtonItem
{
    if (_hideFrontViewControllerButtonItem == nil)
        _hideFrontViewControllerButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Hide" style:UIBarButtonItemStylePlain target:self action:@selector(hideFrontViewControllerButtonTapped:)];

    return _hideFrontViewControllerButtonItem;
}

- (void)setFrontViewController:(UIViewController *)frontViewController
{
    if (frontViewController == _frontViewController)
        return;
    
    //remove the current front from the hierarchy
    [_frontViewController removeFromParentViewController];
    [_frontViewController.view removeFromSuperview];
    
    //assign the new one
    _frontViewController = frontViewController;
    
    //set it up
    [self setUpFrontViewController];
}

- (void)setRearViewController:(UIViewController *)rearViewController
{
    if (rearViewController == _rearViewController)
        return;
    
    //remove the current rear controller
    [_rearViewController removeFromParentViewController];
    [_rearViewController.view removeFromSuperview];
    
    //assign the new one
    _rearViewController = rearViewController;
    
    //set the rasterization scale
    _rearViewController.view.layer.rasterizationScale = [UIScreen mainScreen].scale;
    
    //set it up
    [self setUpRearViewController];
}

- (void)setShrinkRearViewControllerAnimation:(BOOL)shrinkRearViewControllerAnimation
{
    if (shrinkRearViewControllerAnimation == _shrinkRearViewControllerAnimation)
        return;
    
    _shrinkRearViewControllerAnimation = shrinkRearViewControllerAnimation;
    
    [self layoutRearViewController];
}

- (void)setStatusBarBackgroundColor:(UIColor *)statusBarBackgroundColor
{
    //This is only necessary on iOS 7 or above
    if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_6_1)
        return;
    
    if (statusBarBackgroundColor == _statusBarBackgroundColor)
        return;
    
    _statusBarBackgroundColor = statusBarBackgroundColor;
    
    if (self.statusBarUnderlayView == nil)
    {
        self.statusBarUnderlayView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 20.0f)];
        self.statusBarUnderlayView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        self.statusBarUnderlayView.backgroundColor = _statusBarBackgroundColor;
        self.statusBarUnderlayView.alpha = 0.0f;
        [self.view addSubview:self.statusBarUnderlayView];
    }
    else
    {
        self.statusBarUnderlayView.backgroundColor = _statusBarBackgroundColor;
    }
}

- (BOOL)frontViewControllerIsVisible
{
    return (self.frontControllerOffsetRatio >= 1.0f - FLT_EPSILON);
}

@end

/*******************************************************************/

@implementation UIViewController (TORevealViewController)

- (TORevealViewController *)revealViewController
{
    UIViewController *viewController = self;
    while ((viewController = viewController.parentViewController))
    {
        if ([viewController isKindOfClass:[TORevealViewController class]])
            return (TORevealViewController *)viewController;
    }
    
    return nil;
}

- (CGFloat)verticalOffsetForRevealViewController
{
    return 0.0f;
}

- (CGSize)contentSizeForRevealViewController
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        return CGSizeMake(320.0f, self.view.bounds.size.height);
    
    return self.view.bounds.size;
}

- (BOOL)scrollViewShouldScrollToTop:(UIScrollView *)scrollView
{
    UIViewController *frontViewController = self.revealViewController.frontViewController;
    UIViewController *rearViewController = self.revealViewController.rearViewController;
    
    if (self == frontViewController && !self.revealViewController.frontViewControllerIsVisible)
        return NO;
    
    if (self == rearViewController && self.revealViewController.frontViewControllerIsVisible)
        return NO;
    
    return YES;
}

@end
