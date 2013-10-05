//
//  CHDraggableView+Avatar.h
//  ChatHeads
//
//  Created by Matthias Hochgatterer on 4/19/13.
//  Copyright (c) 2013 Matthias Hochgatterer. All rights reserved.
//

#import "CHDraggableView.h"
#import "CHAvatarView.h"

@interface CHDraggableView (Avatar)

+ (id)draggableViewWithImage:(UIImage *)image;
+ (id)draggableViewWithImageView:(CHAvatarView *)avatarView;

@end
