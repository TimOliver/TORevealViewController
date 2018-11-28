//
//  TORevealViewController.m
//
//  Copyright 2014-2018 Timothy Oliver. All rights reserved.
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

#define REVEAL_VIEW_CONTROLLER_DEFAULT_FRONT_SIZE CGSizeMake(375.0f, self.view.bounds.size.height)

#ifndef NSFoundationVersionNumber_iOS_6_1
#define NSFoundationVersionNumber_iOS_6_1 993.00
#endif

#import <QuartzCore/QuartzCore.h>
#import "TORevealViewController.h"

@interface TORevealViewController () <UIGestureRecognizerDelegate>

@property (nonatomic, assign) CGFloat verticalOffset;
@property (nonatomic, assign) CGFloat frontControllerOffsetRatio; /* The current extent that the front view controller is visible (0.0 to 1.0) */
@property (nonatomic, assign) CGFloat panTranslationOriginX; /* Initial X co-ord when panning started. */

@property (nonatomic, strong) UIPanGestureRecognizer *panGestureRecognizer; /* Handles any panning gestures to display the front view controller */
@property (nonatomic, strong) UITapGestureRecognizer *tapGestureRecognizer; /* Recognizes any taps that will trigger the hiding of the front view controller */

@property (nonatomic, strong) CADisplayLink *displayLink; /* Links to the screen vsync to track animation updates. */

@property (nonatomic, strong) UIView *frontContainerView;
@property (nonatomic, strong, readwrite) UIBarButtonItem *showFrontViewControllerButtonItem; /* Used to trigger the displaying of the front view controller */
@property (nonatomic, strong, readwrite) UIBarButtonItem *hideFrontViewControllerButtonItem; /* Used to trigger the displaying of the front view controller */
@property (nonatomic, strong) UIView *blackOverlayView; /* Dark overlay shown beneath the front controller when visible. */
@property (nonatomic, strong) UIView *statusBarUnderlayView; /* Optionally shown under the status bar when the front controller appears. */

@property (nonatomic, assign) BOOL viewIsHiddenOrRemoved; /* State tracking for when the view is taken offscreen */

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
    _rearContentDarkOpacity = 0.55f;
    _showShadowUnderFrontViewController = YES;
}

- (void)loadView
{
    self.view = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.view.opaque = NO;
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.view.backgroundColor = [UIColor clearColor];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    //set up the container for the front view controller
    self.frontContainerView = [[UIView alloc] init];
    
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

- (UIViewController *)childViewControllerForStatusBarStyle
{
    return self.rearViewController;
}

- (UIViewController *)childViewControllerForStatusBarHidden
{
    return self.rearViewController;
}

- (void)viewWillAppear:(BOOL)animated
{
    self.viewIsHiddenOrRemoved = NO;
    
    [super viewWillAppear:animated];
    [self resetLayout];
    
    [self.frontViewController viewWillAppear:animated];
    [self.rearViewController viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self resetLayout];
    
    [self.frontViewController viewDidAppear:animated];
    [self.rearViewController viewDidAppear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
    self.viewIsHiddenOrRemoved = YES;
    
    [super viewDidDisappear:animated];
    [self resetLayout];
    
    [self.frontViewController viewDidDisappear:animated];
    [self.rearViewController viewDidDisappear:animated];
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
    
    if (targetViewController == nil) {
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
            frame.size = CGSizeMake(375.0f, self.view.bounds.size.height);
        else
            frame.size = self.view.bounds.size;
    }
    
    //set the size
    if (self.frontViewControllerContentSize.width > 0.0f + FLT_EPSILON)
        frame.size = self.frontViewControllerContentSize;
    else if ([targetViewController respondsToSelector:@selector(contentSizeForRevealViewController)])
        frame.size = [targetViewController contentSizeForRevealViewController];
    
    //make sure the size isn't bigger than the view space
    frame.size.height = MIN(CGRectGetHeight(frame), CGRectGetHeight(self.view.bounds));
    
    //set the vertical co-ordinates
    if (self.frontViewControllerVerticalOffset > 0.0f)
        self.verticalOffset = self.frontViewControllerVerticalOffset;
    else if ([targetViewController respondsToSelector:@selector(verticalOffsetForRevealViewController)])
        self.verticalOffset = [targetViewController verticalOffsetForRevealViewController];
    else
        self.verticalOffset = 0.0f;
    
    frame.origin.y = self.verticalOffset;
    
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

- (void)resetRearViewController
{
    if (self.shrinkRearViewControllerAnimation == NO)
        return;
    
    self.rearViewController.view.transform = CGAffineTransformIdentity;
    self.rearViewController.view.frame = self.view.bounds;
}

- (void)setUpFrontViewController
{
    if (self.frontViewController == nil)
        return;
    
    //add the new one to the hierarchy
    [self addChildViewController:self.frontViewController];
    
    //set up the view size
    CGRect frame = [self frameForFrontViewControllerHidden:YES];
    
    self.frontContainerView.frame = frame;
    self.frontContainerView.hidden = YES;
    
    self.frontViewController.view.frame = (CGRect){CGPointZero, frame.size};
    self.frontViewController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    [self.frontContainerView addSubview:self.frontViewController.view];
    [self.view addSubview:self.frontContainerView];
    
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
    
    //add a shadow
    if (self.showShadowUnderFrontViewController) {
        self.frontViewController.view.layer.shadowColor = [UIColor blackColor].CGColor;
        self.frontViewController.view.layer.shadowOpacity  = 0.0f;
        self.frontViewController.view.layer.shadowRadius = 10.0f;
        self.frontViewController.view.layer.shadowPath = [UIBezierPath bezierPathWithRect:self.frontViewController.view.bounds].CGPath;
    }
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

- (void)cancelAllAnimations
{
    [self.frontContainerView.layer removeAllAnimations];
    [self.statusBarUnderlayView.layer removeAllAnimations];
    [self.rearViewController.view.layer removeAllAnimations];
    [self.blackOverlayView.layer removeAllAnimations];
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
    CGRect frame = [(CALayer *)self.frontContainerView.layer.presentationLayer frame];
    if (frame.size.width < 0.0f + FLT_EPSILON)
        return;
    
    //Work out as a percentage, at what completion state of the animation it's at
    CGFloat completionRatio = 1.0f - (frame.origin.x / (-frame.size.width));
    completionRatio = MIN(completionRatio, 1.0f);
    completionRatio = MAX(completionRatio, 0.0f);
    
    self.frontControllerOffsetRatio = completionRatio;
    [self layoutContent];
}

- (void)resetLayout
{
    self.frontContainerView.frame = ({
        CGRect frame = self.frontContainerView.frame;
        BOOL isHidden = CGRectGetMinX(frame) < 0.0f - FLT_EPSILON;
        
        frame = [self frameForFrontViewControllerHidden:isHidden];
        if (isHidden == NO)
            frame.origin.x = 0.0f;
        
        frame;
    });
    
    [self resetRearViewController];
    [self layoutContent];
}

- (void)layoutContent
{
    CGFloat completionRatio = self.frontControllerOffsetRatio;
    CGSize frontControllerSize = self.frontContainerView.frame.size;
    
    //if the front view controller is completely off-screen, hide it
    if (self.frontControllerOffsetRatio <= 0.0f + FLT_EPSILON) {
        if (self.frontContainerView.hidden == NO) {
            self.frontContainerView.hidden = YES;
        }
    }
    else {
        if (self.frontContainerView.hidden == YES) {
            self.frontContainerView.hidden = NO;
        }
    }
    
    //if the front view controller has completeley obscured the rear view controller, hide it
    if (CGSizeEqualToSize(frontControllerSize, self.view.bounds.size) && completionRatio >= 1.0f - FLT_EPSILON) {
        if (self.rearViewController.view.hidden == NO) {
            self.rearViewController.view.hidden = YES;
            
            self.rearViewController.view.transform = CGAffineTransformIdentity;
            self.rearViewController.view.frame = self.view.bounds;
            
            //iOS 8 resizing hack
            self.frontContainerView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        }
    }
    else if (completionRatio >= 1.0f - FLT_EPSILON && !CGSizeEqualToSize(frontControllerSize, self.view.bounds.size)) {
        self.frontContainerView.autoresizingMask = UIViewAutoresizingFlexibleHeight;
    }
    else {
        if (self.rearViewController.view.hidden)
            self.rearViewController.view.hidden = NO;
        
        self.frontContainerView.autoresizingMask = UIViewAutoresizingNone;
    }

    if (self.showShadowUnderFrontViewController) {
        self.frontViewController.view.layer.shadowOpacity = completionRatio;
    }

    [self updateViewsWithCompletionRatio:completionRatio];
}

- (void)updateViewsWithCompletionRatio:(CGFloat)completionRatio
{
    if (self.statusBarUnderlayView)
        self.statusBarUnderlayView.alpha = completionRatio;
    
    //change the opacity of the black overlay to match the current completion percentage
    self.blackOverlayView.alpha = MIN(completionRatio * self.rearContentDarkOpacity, self.rearContentDarkOpacity);
    
    //change the sizing of the rear layer's transform
    if (self.shrinkRearViewControllerAnimation && !self.viewIsHiddenOrRemoved && self.rearViewController.view.hidden == NO) {
        
        CGFloat scale = 0.15f;
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
            scale = 0.06f;
        
        CGFloat transformScale = 1.0f - (scale * completionRatio);
        self.rearViewController.view.transform = CGAffineTransformScale(CGAffineTransformIdentity, transformScale, transformScale);
    }
    else
        self.rearViewController.view.transform = CGAffineTransformIdentity;
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
    [self setFrontViewControllerHidden:hidden animated:animated fromVelocity:0.0f completionHandler:nil];
}

- (void)setFrontViewControllerHidden:(BOOL)hidden animated:(BOOL)animated completionHandler:(void (^)(void))completionHandler
{
    [self setFrontViewControllerHidden:hidden animated:animated fromVelocity:0.0f completionHandler:completionHandler];
}

- (void)setFrontViewControllerHidden:(BOOL)hidden animated:(BOOL)animated fromVelocity:(CGFloat)velocity completionHandler:(void (^)(void))completionHandler
{
    CGRect frame = self.frontContainerView.frame;
    
    //send off an alert to the controller before we animate
    if (!hidden) {
        [self.frontViewController viewWillAppear:animated];
        for (UIViewController *child in self.frontViewController.childViewControllers)
            [child viewWillAppear:animated];
    }
    else {
        [self.frontViewController viewWillDisappear:animated];
        for (UIViewController *child in self.frontViewController.childViewControllers)
            [child viewWillDisappear:animated];
    }
    
    /* Inform any view controllers implementing this alert */
    if ([self.frontViewController respondsToSelector:@selector(revealViewControllerWillSetHidden:)])
        [self.frontViewController revealViewControllerWillSetHidden:hidden];
    
    //check if any child controllers of the front controller implement it
    for (UIViewController *controller in self.frontViewController.childViewControllers) {
        if ([controller respondsToSelector:@selector(revealViewControllerWillSetHidden:)])
            [controller revealViewControllerWillSetHidden:hidden];
    }
    
    if ([self.rearViewController respondsToSelector:@selector(revealViewControllerWillSetHidden:)])
        [self.rearViewController revealViewControllerWillSetHidden:hidden];
    
    for (UIViewController *controller in self.rearViewController.childViewControllers) {
        if ([controller respondsToSelector:@selector(revealViewControllerWillSetHidden:)])
            [controller revealViewControllerWillSetHidden:hidden];
    }
    
    /* Set as hidden */
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
        self.frontContainerView.frame = frame;
        [self layoutContent];
        
        if (hidden)
            [self.frontViewController viewDidDisappear:animated];
        else
            [self.frontViewController viewDidAppear:animated];
        
        if (completionHandler)
            completionHandler();
    }
    else
    {
        CGPoint translatedFromPoint = [self.frontContainerView.layer.presentationLayer frame].origin;
        CGPoint translatedToPoint = frame.origin;
        
        translatedFromPoint.x = MIN(0,translatedFromPoint.x);
        translatedFromPoint.x = MAX(-frame.size.width, translatedFromPoint.x);
        
        translatedToPoint.x = MIN(0,translatedToPoint.x);
        translatedToPoint.x = MAX(-frame.size.width, translatedToPoint.x);
        
        CGFloat delta = fabs(translatedFromPoint.x - translatedToPoint.x);
        if (velocity > FLT_EPSILON && delta > 1.0f + FLT_EPSILON) {
            velocity /= delta;
        }
        else {
            velocity = 1.0f;
        }

        velocity = MIN(velocity, 30.0f);
        
        //NSLog(@"From: %f To: %f Velocity: %f", translatedFromPoint.x, translatedToPoint.x, velocity);
        [self cancelAllAnimations];
        
        CGFloat ratio = delta / frame.size.width;
        self.frontContainerView.hidden = NO;
        self.rearViewController.view.hidden = NO;
        [self updateViewsWithCompletionRatio:hidden ? ratio : 1.0f - ratio];
        
        self.frontContainerView.frame = (CGRect){translatedFromPoint, self.frontContainerView.frame.size};
        [UIView animateWithDuration:0.5f delay:0.0f usingSpringWithDamping:1.0f initialSpringVelocity:velocity options:UIViewAnimationOptionAllowUserInteraction animations:^{
            self.frontContainerView.frame = (CGRect){translatedToPoint, self.frontContainerView.frame.size};
            [self updateViewsWithCompletionRatio:hidden?0.0f:1.0f];
        } completion:^(BOOL finished) {
            
            if (!finished) {
                if (completionHandler)
                    completionHandler();
                
                return;
            }
            
            //lock in one more poll of the completion ratio
            CGRect frame = self.frontContainerView.frame;
            self.frontControllerOffsetRatio = 1.0f - (frame.origin.x / (-frame.size.width));
            [self layoutContent];
            
            NSInteger origin = (NSInteger)frame.origin.x;
            if (origin >= 0)
                [self.frontViewController viewDidAppear:YES];
            else if (origin <= -CGRectGetMinX(frame))
                [self.frontViewController viewDidDisappear:YES];
            
            if (completionHandler)
                completionHandler();
        }];

        // Animate the shadow opacity
        if (self.showShadowUnderFrontViewController) {
            CALayer *layer = self.frontViewController.view.layer;
            CABasicAnimation *anim = [CABasicAnimation animationWithKeyPath:@"shadowOpacity"];
            anim.fromValue = [NSNumber numberWithFloat:layer.shadowOpacity];
            anim.toValue = [NSNumber numberWithFloat:hidden ? 0.0f : 1.0f];
            anim.duration = 0.5;
            [layer addAnimation:anim forKey:@"shadowOpacity"];
            layer.shadowOpacity = [(NSNumber *)anim.toValue floatValue];
        }
    }
}

#pragma mark -
#pragma mark Gesture Recognition
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer == self.panGestureRecognizer && self.canPresentWithGesture)
    {
        CGPoint translation = [self.panGestureRecognizer translationInView:self.view];
        CGRect frame = self.frontContainerView.frame;
        
        // if the front view is hidden, only activate if travelling to the right
        if (CGRectGetMinX(frame) <= -(CGRectGetWidth(frame) - FLT_EPSILON))
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
        CGRect frame = [(CALayer *)self.frontContainerView.layer.presentationLayer frame];
        
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
    CGRect frame = [(CALayer *)self.frontContainerView.layer.presentationLayer frame];

    //Sanity check what we get from the presentation layer
    frame.origin.x = MIN(0,frame.origin.x);
    frame.origin.x = MAX(-frame.size.width, frame.origin.x);
    frame.origin.y = self.verticalOffset;
    
    //the pan gesture recognizer doesn't store the offset delta, but the translation SINCE tapping down
    //so to work this out, we need to save the original position of the front view controller when we started
    if (panGestureRecognizer.state == UIGestureRecognizerStateBegan)
    {
        [self cancelAllAnimations];
        
        //if we swiped mid-animation, cancel the animation and set the new origin to the frame canceled at
        if ([self.frontContainerView.layer animationForKey:@"position"])
        {
            [self.frontContainerView.layer removeAllAnimations];
            self.frontContainerView.frame = frame;
        }
        
        self.panTranslationOriginX = frame.origin.x;
    }
    
    //work out the new frame of the front view controller
    frame.origin.x = self.panTranslationOriginX + offset;
    
    //cap it so it can't go furthur to the left
    frame.origin.x = MAX(frame.origin.x, -frame.size.width);
    frame.origin.x = MIN(frame.origin.x, 0.0f);
    
    //save the offset as a ratio for manual updates later
    self.frontContainerView.frame = frame;
    
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
            [self setFrontViewControllerHidden:NO animated:YES fromVelocity:velocityX completionHandler:nil];
        }
        else if (velocityX < -300.0f) //moving fast to the right
        {
            [self setFrontViewControllerHidden:YES animated:YES fromVelocity:fabs(velocityX) completionHandler:nil];
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
- (BOOL)shouldAutorotate
{
    return [self.rearViewController shouldAutorotate];
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    if ([self.view.layer animationForKey:@"bounds"]) {
        CGRect frame = [self frameForFrontViewControllerHidden:!self.frontViewControllerIsVisible];
        self.frontContainerView.frame = frame;
    }
}

-(void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        //set the new frame for the front view controller based on the new orientation
        self.frontContainerView.frame = [self frameForFrontViewControllerHidden:!self.frontViewControllerIsVisible];
        self.frontViewController.view.layer.shadowPath = [UIBezierPath bezierPathWithRect:self.frontViewController.view.bounds].CGPath;
        
        //reset the size of the rear view controller
        if (self.rearViewController.view.superview)
            [self resetRearViewController];
        
        //layout all of the content
        [self layoutContent];
    } completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        //reset the frame of the front view controller
        if (self.frontViewControllerIsVisible)
            self.frontContainerView.frame = [self frameForFrontViewControllerHidden:NO];
        
        //layout the content
        [self layoutContent];
    }];
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
    
    [self resetRearViewController];
    [self layoutContent];
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

- (CGSize)contentSizeForRevealViewController
{
    return CGSizeMake(375.0f, 1024.0f);
}

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

- (void)revealViewControllerWillSetHidden:(BOOL)hidden
{
    //Do nothing
}

@end
