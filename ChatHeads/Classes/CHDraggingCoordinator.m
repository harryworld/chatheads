//
//  CHDraggingCoordinator.m
//  ChatHeads
//
//  Created by Matthias Hochgatterer on 4/19/13.
//  Copyright (c) 2013 Matthias Hochgatterer. All rights reserved.
//

#import "CHDraggingCoordinator.h"
#import <QuartzCore/QuartzCore.h>
#import "CHDraggableView.h"

#import "XPConnection.h"

typedef enum {
    CHInteractionStateNormal,
    CHInteractionStateConversation
} CHInteractionState;

@interface CHDraggingCoordinator ()

@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) NSMutableDictionary *edgePointDictionary;;
@property (nonatomic, assign) CGRect draggableViewBounds;
@property (nonatomic, assign) CHInteractionState state;
@property (nonatomic, strong) UINavigationController *presentedNavigationController;
@property (nonatomic, strong) UIView *backgroundView;

@end

@implementation CHDraggingCoordinator

- (id)initWithWindow:(UIWindow *)window draggableViewBounds:(CGRect)bounds
{
    self = [super init];
    if (self) {
        _window = window;
        _draggableViewBounds = bounds;
        _state = CHInteractionStateNormal;
        _edgePointDictionary = [NSMutableDictionary dictionary];
    }
    return self;
}

#pragma mark - Geometry

- (CGRect)_dropArea
{
    return CGRectInset([self.window.screen applicationFrame], -(int)(CGRectGetWidth(_draggableViewBounds)/6), 0);
}

- (CGRect)_conversationArea
{
    CGRect slice;
    CGRect remainder;
    NSLog(@"drag 1: %@", NSStringFromCGRect(_draggableViewBounds));
    CGRectDivide([self.window.screen applicationFrame], &slice, &remainder, CGRectGetHeight(CGRectInset(_draggableViewBounds, -10, +10)), CGRectMinYEdge);
    NSLog(@"application: %@", NSStringFromCGRect([self.window.screen applicationFrame]));
    NSLog(@"drag 2: %@", NSStringFromCGRect(CGRectInset(_draggableViewBounds, -10, +10)));
    NSLog(@"drag height: %f", CGRectGetHeight(CGRectInset(_draggableViewBounds, -10, +10)));
    return slice;
}

- (CGRectEdge)_destinationEdgeForReleasePointInCurrentState:(CGPoint)releasePoint
{
    if (_state == CHInteractionStateConversation) {
        return CGRectMinYEdge;
    } else if(_state == CHInteractionStateNormal) {
        return releasePoint.x < CGRectGetMidX([self _dropArea]) ? CGRectMinXEdge : CGRectMaxXEdge;
    }
    NSAssert(false, @"State not supported");
    return CGRectMinYEdge;
}

- (CGPoint)_destinationPointForReleasePoint:(CGPoint)releasePoint
{
    CGRect dropArea = [self _dropArea];
    
    CGFloat midXDragView = CGRectGetMidX(_draggableViewBounds);
    CGRectEdge destinationEdge = [self _destinationEdgeForReleasePointInCurrentState:releasePoint];
    CGFloat destinationY;
    CGFloat destinationX;
 
    CGFloat topYConstraint = CGRectGetMinY(dropArea) + CGRectGetMidY(_draggableViewBounds);
    CGFloat bottomYConstraint = CGRectGetMaxY(dropArea) - CGRectGetMidY(_draggableViewBounds);
    if (releasePoint.y < topYConstraint) { // Align ChatHead vertically
        destinationY = topYConstraint;
    }else if (releasePoint.y > bottomYConstraint) {
        destinationY = bottomYConstraint;
    }else {
        destinationY = releasePoint.y;
    }

    if (self.snappingEdge == CHSnappingEdgeBoth){   //ChatHead will snap to both edges
        if (destinationEdge == CGRectMinXEdge) {
            destinationX = CGRectGetMinX(dropArea) + midXDragView;
        } else {
            destinationX = CGRectGetMaxX(dropArea) - midXDragView;
        }
        
    }else if(self.snappingEdge == CHSnappingEdgeLeft){  //ChatHead will snap only to left edge
        destinationX = CGRectGetMinX(dropArea) + midXDragView;
        
    }else{  //ChatHead will snap only to right edge
        destinationX = CGRectGetMaxX(dropArea) - midXDragView;
    }

    return CGPointMake(destinationX, destinationY);
}

#pragma mark - Dragging

- (void)draggableViewHold:(CHDraggableView *)view
{
    
}

- (void)draggableView:(CHDraggableView *)view didMoveToPoint:(CGPoint)point
{
    if (_state == CHInteractionStateConversation) {
        if (_presentedNavigationController) {
            [self _dismissPresentedNavigationController];
        }
    }
}

- (void)draggableViewReleased:(CHDraggableView *)view
{
    if (_state == CHInteractionStateNormal) {
        [self _animateViewToEdges:view];
    } else if(_state == CHInteractionStateConversation) {
        [self _animateViewToConversationArea:view];
        [self _presentViewControllerForDraggableView:view];
    }
}

- (void)draggableViewTouched:(CHDraggableView *)view
{
    if (_state == CHInteractionStateNormal) {
        _state = CHInteractionStateConversation;
        [self _animateViewToConversationArea:view];
        
        [self _presentViewControllerForDraggableView:view];
    } else if(_state == CHInteractionStateConversation) {
        _state = CHInteractionStateNormal;
        NSValue *knownEdgePoint = [_edgePointDictionary objectForKey:@(view.tag)];
        if (knownEdgePoint) {
            [self _animateView:view toEdgePoint:[knownEdgePoint CGPointValue]];
        } else {
            [self _animateViewToEdges:view];
        }
        [self _dismissPresentedNavigationController];
    }
}

#pragma mark - Alignment

- (void)draggableViewNeedsAlignment:(CHDraggableView *)view
{
    NSLog(@"Align view");
    if (_state == CHInteractionStateNormal) {
        [self _animateViewToEdges:view];
    }
}

#pragma mark Dragging Helper

- (void)_animateViewToEdges:(CHDraggableView *)view
{
    CGPoint destinationPoint = [self _destinationPointForReleasePoint:view.center];    
    [self _animateView:view toEdgePoint:destinationPoint];
}

- (void)_animateView:(CHDraggableView *)view toEdgePoint:(CGPoint)point
{
    [_edgePointDictionary setObject:[NSValue valueWithCGPoint:point] forKey:@(view.tag)];
    [view snapViewCenterToPoint:point edge:[self _destinationEdgeForReleasePointInCurrentState:view.center]];
}

- (void)_animateViewToConversationArea:(CHDraggableView *)view
{
    CGRect conversationArea = [self _conversationArea];
    CGPoint center = CGPointMake(CGRectGetMinX(conversationArea) + 40, CGRectGetMidY(conversationArea) + 10);
    [view snapViewCenterToPoint:center edge:[self _destinationEdgeForReleasePointInCurrentState:view.center]];
}

#pragma mark - View Controller Handling

- (CGRect)_navigationControllerFrame
{
    CGRect slice;
    CGRect remainder;
    CGRectDivide([self.window.screen applicationFrame], &slice, &remainder, CGRectGetMaxY([self _conversationArea]), CGRectMinYEdge);
    return remainder;
}

- (CGRect)_navigationControllerHiddenFrame
{
    return CGRectMake(CGRectGetMidX([self _conversationArea]), CGRectGetMaxY([self _conversationArea]), 0, 0);
}

- (void)_presentViewControllerForDraggableView:(CHDraggableView *)draggableView
{
    UIViewController *viewController = [_delegate draggingCoordinator:self viewControllerForDraggableView:draggableView];
    NSLog(@"viewController: %@", NSStringFromCGRect(viewController.view.frame));
    NSLog(@"drag view: %@", NSStringFromCGRect(draggableView.frame));
    
    _presentedNavigationController = [[UINavigationController alloc] initWithRootViewController:viewController];
    _presentedNavigationController.view.layer.cornerRadius = 3;
    _presentedNavigationController.view.layer.masksToBounds = YES;
    _presentedNavigationController.view.layer.anchorPoint = CGPointMake(0.5f, 0);
    _presentedNavigationController.view.frame = [self _navigationControllerFrame];
    _presentedNavigationController.view.transform = CGAffineTransformMakeScale(0, 0);
    _presentedNavigationController.navigationBar.hidden = YES;
    NSLog(@"_presentedNavigationController: %@", NSStringFromCGRect(_presentedNavigationController.view.frame));
    
    [self.window insertSubview:_presentedNavigationController.view belowSubview:draggableView];
    [self _unhidePresentedNavigationControllerCompletion:^{}];
}

- (void)_dismissPresentedNavigationController
{
    UINavigationController *reference = _presentedNavigationController;
    [self _hidePresentedNavigationControllerCompletion:^{
        [reference.view removeFromSuperview];
    }];
    _presentedNavigationController = nil;
}

- (void)_unhidePresentedNavigationControllerCompletion:(void(^)())completionBlock
{
    CGAffineTransform transformStep1 = CGAffineTransformMakeScale(1.1f, 1.1f);
    CGAffineTransform transformStep2 = CGAffineTransformMakeScale(1, 1);
    
    _backgroundView = [[UIView alloc] initWithFrame:[self.window bounds]];
    _backgroundView.backgroundColor = [UIColor colorWithWhite:0.000 alpha:0.5f];
    _backgroundView.alpha = 0.0f;
    [self.window insertSubview:_backgroundView belowSubview:_presentedNavigationController.view];
    
    XPConnection *connection = [XPConnection sharedInstance];
    
    _nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(80, 30, 160, 20)];
    _nameLabel.text = connection.staffName;
    _nameLabel.backgroundColor = [UIColor clearColor];
    _nameLabel.font = [UIFont boldSystemFontOfSize:16];
    _nameLabel.shadowOffset = CGSizeMake(0, 1);
    _nameLabel.shadowColor = [UIColor darkGrayColor];
    _nameLabel.textColor = [UIColor whiteColor];
    [self.window insertSubview:_nameLabel aboveSubview:_presentedNavigationController.view];
    
    _statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(80, 50, 160, 20)];
    _statusLabel.text = connection.staffStatus;
    _statusLabel.backgroundColor = [UIColor clearColor];
    _statusLabel.font = [UIFont boldSystemFontOfSize:16];
    _statusLabel.shadowOffset = CGSizeMake(0, 1);
    _statusLabel.shadowColor = [UIColor darkGrayColor];
    _statusLabel.textColor = [UIColor colorWithWhite:1 alpha:0.5];
    [self.window insertSubview:_statusLabel belowSubview:_presentedNavigationController.view];
    
    [UIView animateWithDuration:0.3f delay:0.0f options:UIViewAnimationOptionCurveEaseInOut animations:^{
        _presentedNavigationController.view.layer.affineTransform = transformStep1;
        _backgroundView.alpha = 1.0f;
    }completion:^(BOOL finished){
        if (finished) {
            [UIView animateWithDuration:0.3f animations:^{
                _presentedNavigationController.view.layer.affineTransform = transformStep2;
            }];
        }
    }];
}

- (void)_hidePresentedNavigationControllerCompletion:(void(^)())completionBlock
{
    UIView *viewToDisplay = _backgroundView;
    [UIView animateWithDuration:0.3f delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        _presentedNavigationController.view.transform = CGAffineTransformMakeScale(0, 0);
        _presentedNavigationController.view.alpha = 0.0f;
        _backgroundView.alpha = 0.0f;
        _nameLabel.hidden = YES;
        _statusLabel.hidden = YES;
    } completion:^(BOOL finished){
        if (finished) {
            [viewToDisplay removeFromSuperview];
            if (viewToDisplay == _backgroundView) {
                _backgroundView = nil;
            }
            [_nameLabel removeFromSuperview];
            [_statusLabel removeFromSuperview];
            completionBlock();
        }
    }];
}

@end
